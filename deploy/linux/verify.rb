# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Checks a running WCL Zammad end to end, the way the HR app uses it, through real HTTP calls.
# Leaves nothing behind (its customer, ticket, token and test departments are removed).
#
#   docker compose exec -T zammad-railsserver bundle exec rails r - < verify.rb
#
# Optional: VERIFY_URL=https://support.example.com to go through the public address (Caddy)
# instead of the internal nginx.

require 'net/http'
require 'json'
require 'base64'

BASE = ENV.fetch('VERIFY_URL', 'http://zammad-nginx:8080').chomp('/')
RESULTS = [] # rubocop:disable Style/MutableConstant

def parse_json(body)
  JSON.parse(body)
rescue JSON::ParserError
  body
end

def check(name)
  ok, detail = yield
  RESULTS << [ok, name, detail]
  suffix = detail ? " - #{detail}" : ''
  puts "#{ok ? 'PASS' : 'FAIL'}  #{name}#{suffix}"
rescue => e
  RESULTS << [false, name, e.message]
  puts "FAIL  #{name} - #{e.class}: #{e.message}"
end

# Records made here (outside a request) are made by the system user.
UserInfo.current_user_id = 1

admin = User.with_permissions('admin.user').where(active: true).where.not(id: 1).first
abort 'No active admin user yet: finish the Zammad setup wizard first.' if !admin

token = Token.create!(action: 'api', name: 'WCL verify (temporary)', user_id: admin.id,
                      preferences: { permission: %w[admin.user ticket.agent admin.overview] }, persistent: true)
customer_email = "wcl-verify-#{SecureRandom.hex(4)}@example.invalid"
ticket_id = nil
# The department test adds a department; the real list is put back at the end.
department_option_before = ObjectManager::Attribute.get(object: 'User', name: 'department')&.data_option&.deep_dup

http = lambda do |method, path, body: nil, from: nil, raw: false|
  uri = URI("#{BASE}/api/v1/#{path}")
  request = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
  request['Authorization'] = "Token token=#{token.token}"
  request['Content-Type'] = 'application/json'
  request['From'] = from if from
  request.body = body.to_json if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 60) { |h| h.request(request) }
  next [response.code.to_i, response] if raw

  [response.code.to_i, parse_json(response.body)]
end

begin
  check('web: login page answers') do
    response = Net::HTTP.get_response(URI("#{BASE}/"))
    [response.code == '200', "HTTP #{response.code}"]
  end

  check('setup: WCL data (states, priorities, fields, settings)') do
    missing = []
    missing << 'rejected state' if !Ticket::State.exists?(name: 'rejected')
    missing << 'urgent priority' if Ticket::Priority.find_by(name: '4 urgent')&.ui_color != 'urgent-priority'
    missing << 'Owners field' if !ObjectManager::Attribute.get(object: 'Ticket', name: 'assignees')
    missing << 'Show in HR app' if !ObjectManager::Attribute.get(object: 'Group', name: 'hr_portal')
    missing << 'Departments list' if !Department.table_exists?
    missing << 'department dropdown' if ObjectManager::Attribute.get(object: 'User', name: 'department')&.data_type != 'tree_select'
    missing << 'attachment settings' if Setting.get('hr_portal_attachment_extensions').nil?
    missing << 'open-requests overview' if !Overview.exists?(link: 'hr_portal_open')
    missing << 'In Progress / On Hold states' if Ticket::State.where(name: ['in progress', 'on hold']).count != 2
    missing << 'ticket Department' if !ObjectManager::Attribute.get(object: 'Ticket', name: 'department')
    missing << 'Manager role' if !Role.exists?(name: 'Manager') || !Overview.exists?(link: 'wcl_team_open')
    missing << 'Category field' if !ObjectManager::Attribute.get(object: 'Ticket', name: 'category')
    missing << 'hidden state on new tickets' if !CoreWorkflow.exists?(name: 'WCL: Customers do not pick the state of a new ticket')
    missing << 'Location field' if !ObjectManager::Attribute.get(object: 'Ticket', name: 'location')
    missing << 'Category by group' if !CoreWorkflow.exists?(name: 'WCL: Category follows the group')
    missing << 'weekly manager summary' if Setting.get('wcl_manager_summary').nil? || !Scheduler.exists?(method: 'Wcl::ManagerSummary.deliver_all')
    [missing.empty?, missing.empty? ? nil : "missing: #{missing.join(', ')} (run: rails zammad:wcl:setup)"]
  end

  check('search: Elasticsearch answers') do
    url = Setting.get('es_url')
    next [false, 'es_url not set'] if url.blank?

    response = Net::HTTP.get_response(URI(url))
    [response.code == '200', "#{url} HTTP #{response.code}"]
  end

  check('API: attachment rules endpoint') do
    code, json = http.call(:get, 'wcl/attachment_rules')
    [code == 200 && json['extensions'].is_a?(Array) && json['max_bytes'].to_i.positive?, "HTTP #{code} #{json}"]
  end

  check('department: listed in Departments, offered in the dropdown') do
    Department.create!(name: 'WCL Verify Dept', active: true, created_by_id: 1, updated_by_id: 1)
    options = Array(ObjectManager::Attribute.get(object: 'User', name: 'department').reload.data_option['options']).pluck('value')
    [options.include?('WCL Verify Dept'), "options: #{options.first(5)}..."]
  end

  check('API: customer created with a location organization') do
    code, = http.call(:post, 'users', body: { firstname: 'WCL', lastname: 'Verify', email: customer_email,
                                                   organization: 'ZZ: WCL Verify', roles: ['Customer'] })
    if [422, 404].include?(code)
      Organization.create!(name: 'ZZ: WCL Verify', shared: false)
      code, = http.call(:post, 'users', body: { firstname: 'WCL', lastname: 'Verify', email: customer_email,
                                                     organization: 'ZZ: WCL Verify', roles: ['Customer'] })
    end
    [code == 201, "HTTP #{code}"]
  end

  # A group employees may pick that the checking admin also works in (agents' side of the checks).
  group = Group.where(active: true).find { |g| (!g.respond_to?(:hr_portal) || g.hr_portal) && admin.group_access?(g.id, 'full') }
  abort 'No group that customers can pick and the admin works in: create one (Admin → Groups) first.' if !group

  attachment_text = "wclverify#{SecureRandom.hex(3)} payslip discrepancy"

  check('API: employee files a ticket with an attachment (urgent, tagged)') do
    urgent = Ticket::Priority.find_by(name: '4 urgent')
    code, json = http.call(:post, 'tickets?expand=true', from: customer_email, body: {
                             title: 'WCL verify ticket', group_id: group.id, priority_id: urgent&.id, tags: 'hr-portal',
                             location: 'WCL verify location',
                             article: { subject: 'WCL verify', body: 'Please check the attached file.', type: 'web',
                                        internal: false, content_type: 'text/plain',
                                        attachments: [{ 'filename' => 'verify.txt', 'mime-type' => 'text/plain',
                                                        'data' => Base64.strict_encode64(attachment_text) }] },
                           })
    ticket_id = json['id'] if code == 201
    [code == 201 && json['priority'] == '4 urgent', "HTTP #{code} group=#{group.name} #{json['error'] if json.is_a?(Hash)}".strip]
  end

  check('API: employee reads the thread and downloads the file') do
    code, articles = http.call(:get, "ticket_articles/by_ticket/#{ticket_id}?expand=true", from: customer_email)
    article = articles.first
    file = article['attachments'].first
    dcode, response = http.call(:get, "ticket_attachment/#{ticket_id}/#{article['id']}/#{file['id']}", from: customer_email, raw: true)
    [code == 200 && dcode == 200 && response.body == attachment_text, "HTTP #{code}/#{dcode}"]
  end

  check('API: another employee is refused the ticket') do
    other = "wcl-verify-other-#{SecureRandom.hex(3)}@example.invalid"
    User.create!(firstname: 'Other', lastname: 'Verify', email: other, roles: Role.where(name: 'Customer'))
    code, = http.call(:get, "tickets/#{ticket_id}", from: other)
    User.find_by(email: other)&.destroy
    [[403, 404].include?(code), "HTTP #{code}"]
  end

  check('API: reply, owners and subscribers') do
    code, = http.call(:post, 'ticket_articles', from: customer_email,
                                                body: { ticket_id: ticket_id, body: 'More details', type: 'web', internal: false, content_type: 'text/plain' })
    # Agents who may already work in the group; nothing about them is changed.
    agents = User.with_permissions('ticket.agent').where(active: true).where.not(id: 1)
      .select { |agent| agent.group_access?(group.id, 'full') }.first(2)
    next [false, "no agent has full access to group #{group.name}"] if agents.empty?

    ucode, json = http.call(:put, "tickets/#{ticket_id}", body: { assignees: agents.map { |a| a.id.to_s } })
    _, mentions = http.call(:get, "mentions?mentionable_type=Ticket&mentionable_id=#{ticket_id}")
    subscribed = mentions['mentions'].pluck('user_id').sort
    ok = code == 201 && ucode == 200 && json['owner_id'] == agents.first.id && subscribed == agents.map(&:id).sort
    [ok, "reply HTTP #{code}, owner=#{json['owner_id']}, subscribed=#{subscribed} (agents #{agents.map(&:id)})"]
  end

  check('closing needs a note: refused without one') do
    code, = http.call(:put, "tickets/#{ticket_id}", body: { state: 'rejected' })
    [code == 422 && Ticket.uncached { Ticket.find(ticket_id).state.name } != 'rejected', "HTTP #{code}"]
  end

  check('API: Rejected state (needs a public note)') do
    internal = { body: 'verify: internal reason', type: 'note', internal: true }
    code_internal, = http.call(:put, "tickets/#{ticket_id}", body: { state: 'rejected', article: internal })
    next [false, "an internal note was accepted for Rejected (HTTP #{code_internal})"] if code_internal != 422

    note = { body: 'verify: rejected with a reason', type: 'note', internal: false }
    code, json = http.call(:put, "tickets/#{ticket_id}", body: { state: 'rejected', article: note })
    [code == 200 && Ticket.uncached { Ticket.find(ticket_id).state.name } == 'rejected', "HTTP #{code} #{json.is_a?(Hash) ? json['state_id'] : json}"]
  end

  check('search: finds the ticket by text inside its attachment') do
    SearchIndexBackend.refresh if SearchIndexBackend.respond_to?(:refresh)
    found = false
    20.times do
      Ticket.find(ticket_id).search_index_update_backend
      SearchIndexBackend.refresh if SearchIndexBackend.respond_to?(:refresh)
      code, json = http.call(:get, "tickets/search?query=#{attachment_text.split.first}&limit=5")
      ids   = if json.is_a?(Array)
                json.pluck('id')
              else
                Array(json.is_a?(Hash) ? json['tickets'] : nil)
              end
      found = code == 200 && ids.include?(ticket_id)
      break if found

      sleep 3
    end
    [found, found ? nil : 'not found (is the Elasticsearch attachment processor available?)']
  end
ensure
  Ticket.find_by(id: ticket_id)&.destroy if ticket_id
  User.find_by(email: customer_email)&.destroy
  User.where('email LIKE ?', 'wcl-verify-other-%@example.invalid').find_each(&:destroy)
  Department.find_by(name: 'WCL Verify Dept')&.destroy if defined?(Department) && Department.table_exists?
  Organization.find_by(name: 'ZZ: WCL Verify')&.destroy
  attribute = ObjectManager::Attribute.get(object: 'User', name: 'department')
  attribute.update!(data_option: department_option_before) if attribute && department_option_before
  token.destroy
end

failed = RESULTS.reject(&:first)
puts
puts failed.empty? ? "All #{RESULTS.size} checks passed." : "#{failed.size} of #{RESULTS.size} checks FAILED."
exit(failed.empty? ? 0 : 1)
