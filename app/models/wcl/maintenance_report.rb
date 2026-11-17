# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the Maintenance report (Reporting > Maintenance Report, and its Excel
# download). For a period and a set of groups it counts tickets submitted, completed, rejected and
# still open, the average completion time (created -> closed), and breaks that down by week,
# month, department, location, category and person (the ticket's main owner). It also lists repeat
# issues (the same category at the same location more than once) and the oldest open ticket.
#
# Only tickets the user may read are counted (TicketPolicy::ReadScope).
class Wcl::MaintenanceReport
  CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze

  attr_reader :user, :from, :to, :group_ids, :timezone

  # from/to: dates (inclusive); group_ids: [] means every group the user can read.
  def initialize(user:, from:, to:, group_ids: [], timezone: nil)
    @user      = user
    @timezone  = timezone.presence || Setting.get('timezone_default').presence || 'UTC'
    @from      = from.to_date
    @to        = to.to_date
    @group_ids = Array(group_ids).compact_blank.map(&:to_i)
  end

  # Everything the page shows, as plain data.
  def data
    @data ||= {
      period:        { from: from.iso8601, to: to.iso8601 },
      groups:        Group.where(id: scope_group_ids).reorder(:name).pluck(:name),
      summary:       summary,
      by_week:       by_period(:week),
      by_month:      by_period(:month),
      by_department: breakdown { |ticket| ticket[:department] if ticket.has_attribute?(:department) },
      by_location:   breakdown { |ticket| location_name(ticket) },
      by_category:   breakdown { |ticket| category_name(ticket) },
      by_person:     by_person,
      repeats:       repeats,
      oldest_open:   oldest_open,
    }
  end

  # "#123 Title (7 days, Owner)", or '' when nothing is open.
  def oldest_open_text
    oldest = data[:oldest_open]
    return '' if !oldest

    "##{oldest[:number]} #{oldest[:title]} (#{oldest[:days_open]} days, #{oldest[:owner]})"
  end

  def filename
    "maintenance-report-#{from.iso8601}-to-#{to.iso8601}.xlsx"
  end

  # The Excel file, deleted from disk already (see ExcelSheet#file); read it before closing.
  def file
    require 'write_xlsx'

    directory = File.join(Dir.tmpdir, "maintenance-report-#{SecureRandom.hex(16)}")
    FileUtils.mkdir(directory, mode: 0o700)
    begin
      path     = File.join(directory, 'report.xlsx')
      workbook = WriteXLSX.new(path, tempdir: File.join(directory, 'package'))
      write_workbook(workbook)
      workbook.close
      File.open(path, 'rb')
    ensure
      FileUtils.rm_rf(directory)
    end
  end

  private

  def zone
    @zone ||= ActiveSupport::TimeZone[timezone] || Time.zone
  end

  def range
    @range ||= zone.local(from.year, from.month, from.day).beginning_of_day..zone.local(to.year, to.month, to.day).end_of_day
  end

  def scope
    TicketPolicy::ReadScope.new(user).resolve.where(group_id: scope_group_ids)
  end

  def scope_group_ids
    @scope_group_ids ||= begin
      readable = readable_group_ids
      group_ids.present? ? (readable & group_ids) : readable
    end
  end

  # Agents (managers): every group they may read, even one without tickets yet.
  def readable_group_ids
    return user.group_ids_access('read') if user.permissions?('ticket.agent')

    TicketPolicy::ReadScope.new(user).resolve.distinct.pluck(:group_id)
  end

  def closed_state_ids
    @closed_state_ids ||= Ticket::State.where(state_type: Ticket::StateType.where(name: 'closed')).pluck(:id)
  end

  def rejected_state_id
    @rejected_state_id ||= Ticket::State.find_by(name: 'rejected')&.id
  end

  def open_state_ids
    @open_state_ids ||= Ticket::State.by_category_ids(:work_on_all)
  end

  # Tickets submitted in the period.
  def submitted
    @submitted ||= scope.where(created_at: range).includes(:owner, :state, :group, :priority, :customer).to_a
  end

  # Tickets completed (closed, not rejected) in the period, whenever they were submitted.
  def completed
    @completed ||= scope.where(close_at: range, state_id: closed_state_ids - [rejected_state_id])
      .includes(:owner, :state, :group, :priority, :customer).to_a
  end

  def rejected
    @rejected ||= scope.where(close_at: range, state_id: rejected_state_id).to_a
  end

  # Open right now, whenever submitted.
  def outstanding
    @outstanding ||= scope.where(state_id: open_state_ids).includes(:owner).to_a
  end

  def days_to_complete(ticket)
    return if ticket.close_at.blank?

    ((ticket.close_at - ticket.created_at) / 1.day).round(2)
  end

  def average_days(tickets)
    days = tickets.filter_map { |ticket| days_to_complete(ticket) }
    return if days.empty?

    (days.sum / days.size).round(2)
  end

  def summary
    {
      submitted:           submitted.size,
      completed:           completed.size,
      rejected:            rejected.size,
      outstanding_now:     outstanding.size,
      average_days:        average_days(completed),
      outcome:             outcome,
      completion_rate_pct: submitted.empty? ? nil : ((submitted.count { |ticket| completed_ids.include?(ticket.id) } * 100.0) / submitted.size).round(1),
    }
  end

  # Where the tickets submitted in the period are now.
  def outcome
    {
      completed: submitted.count { |ticket| closed_state_ids.include?(ticket.state_id) && ticket.state_id != rejected_state_id },
      rejected:  submitted.count { |ticket| ticket.state_id == rejected_state_id },
      open:      submitted.count { |ticket| closed_state_ids.exclude?(ticket.state_id) },
    }
  end

  def completed_ids
    @completed_ids ||= completed.to_set(&:id)
  end

  def period_key(time, unit)
    local = time.in_time_zone(zone).to_date
    unit == :week ? local.beginning_of_week(:monday) : local.beginning_of_month
  end

  def by_period(unit)
    keys = {}
    submitted.each { |ticket| (keys[period_key(ticket.created_at, unit)] ||= { submitted: 0, completed: [] })[:submitted] += 1 }
    completed.each { |ticket| (keys[period_key(ticket.close_at, unit)] ||= { submitted: 0, completed: [] })[:completed] << ticket }
    keys.sort.map do |key, row|
      label = unit == :week ? "#{key.iso8601} (week #{key.cweek})" : key.strftime('%Y-%m')
      { period: label, submitted: row[:submitted], completed: row[:completed].size, average_days: average_days(row[:completed]) }
    end
  end

  # Submitted / completed / still open / average days, per value of the block (blank: "(none)").
  def breakdown(&) # rubocop:disable Metrics/AbcSize
    rows = Hash.new { |hash, key| hash[key] = { submitted: 0, completed: [], open: 0 } }
    submitted.each do |ticket|
      key = yield(ticket).presence || '(none)'
      rows[key][:submitted] += 1
      rows[key][:open] += 1 if open_state_ids.include?(ticket.state_id)
    end
    completed.each { |ticket| rows[yield(ticket).presence || '(none)'][:completed] << ticket }
    rows.sort_by { |key, row| [-row[:submitted], key.to_s.downcase] }.map do |key, row|
      { name: key, submitted: row[:submitted], completed: row[:completed].size, still_open: row[:open], average_days: average_days(row[:completed]) }
    end
  end

  # Per main owner: completed in the period, open now, average days.
  def by_person
    rows = Hash.new { |hash, key| hash[key] = { completed: [], open: 0 } }
    completed.each { |ticket| rows[owner_name(ticket)][:completed] << ticket }
    outstanding.each { |ticket| rows[owner_name(ticket)][:open] += 1 }
    rows.sort_by { |key, row| [-row[:completed].size, key.downcase] }.map do |key, row|
      { name: key, completed: row[:completed].size, open_now: row[:open], average_days: average_days(row[:completed]) }
    end
  end

  # The same category reported at the same location (ignoring case and spaces) more than once in
  # the period: a sign of a recurring problem.
  def repeats # rubocop:disable Metrics/AbcSize
    submitted
      .select { |ticket| location_name(ticket) && category_name(ticket) }
      .group_by { |ticket| [location_name(ticket).downcase, ticket.category.to_s.downcase] }
      .values
      .select { |tickets| tickets.size > 1 }
      .sort_by { |tickets| [-tickets.size, location_name(tickets.first).downcase] }
      .map do |tickets|
        {
          location:   location_name(tickets.first),
          category:   category_name(tickets.first),
          count:      tickets.size,
          still_open: tickets.count { |ticket| open_state_ids.include?(ticket.state_id) },
          tickets:    tickets.sort_by(&:created_at).map { |ticket| "##{ticket.number}" }.join(', '),
        }
      end
  end

  def oldest_open
    ticket = outstanding.min_by(&:created_at)
    return if !ticket

    { id: ticket.id, number: ticket.number, title: ticket.title, days_open: ((Time.current - ticket.created_at) / 1.day).floor, owner: owner_name(ticket) }
  end

  def location_name(ticket)
    return if !ticket.has_attribute?(:location)

    ticket.location.to_s.squish.presence
  end

  def owner_name(ticket)
    ticket.owner_id.to_i <= 1 ? '(unassigned)' : ticket.owner&.fullname.to_s
  end

  def category_name(ticket)
    return if !ticket.has_attribute?(:category) || ticket.category.blank?

    ticket.category.to_s.split('::').last
  end

  def local(time)
    time&.in_time_zone(zone)&.strftime('%Y-%m-%d %H:%M')
  end

  # -- Excel ---------------------------------------------------------------------------------

  def write_workbook(workbook) # rubocop:disable Metrics/AbcSize
    formats = {
      title:  workbook.add_format(bold: 1, size: 14),
      header: workbook.add_format(bold: 1, bg_color: '#DDE1E5', border: 1),
      number: workbook.add_format(num_format: '0.00'),
    }
    write_summary(workbook.add_worksheet('Summary'), formats)
    write_table(workbook.add_worksheet(__('By week')), formats, %w[Week Submitted Completed], data[:by_week], %i[period submitted completed average_days])
    write_table(workbook.add_worksheet(__('By month')), formats, %w[Month Submitted Completed], data[:by_month], %i[period submitted completed average_days])
    breakdown_columns = %i[name submitted completed still_open average_days]
    write_table(workbook.add_worksheet(__('By department')), formats, ['Department', 'Submitted', 'Completed', __('Still open')], data[:by_department], breakdown_columns)
    write_table(workbook.add_worksheet(__('By location')), formats, ['Location', 'Submitted', 'Completed', __('Still open')], data[:by_location], breakdown_columns)
    write_table(workbook.add_worksheet(__('By category')), formats, ['Category', 'Submitted', 'Completed', __('Still open')], data[:by_category], breakdown_columns)
    write_table(workbook.add_worksheet(__('By person')), formats, ['Person', 'Completed', __('Open now')], data[:by_person], %i[name completed open_now average_days])
    write_repeats(workbook.add_worksheet(__('Repeat issues')), formats)
    write_tickets(workbook.add_worksheet('Tickets'), formats)
  end

  def write_summary(sheet, formats) # rubocop:disable Metrics/AbcSize
    sheet.set_column(0, 0, 34)
    sheet.set_column(1, 1, 40)
    sheet.write(0, 0, __('Maintenance report'), formats[:title])
    rows = [
      ['Period', "#{from.iso8601} to #{to.iso8601}"],
      ['Groups', data[:groups].join(', ')],
      [__('Submitted in period'), data[:summary][:submitted]],
      [__('Completed in period'), data[:summary][:completed]],
      [__('Rejected in period'), data[:summary][:rejected]],
      [__('Outstanding now'), data[:summary][:outstanding_now]],
      [__('Average completion time (days)'), data[:summary][:average_days]],
      [__('Submitted in period and completed (%)'), data[:summary][:completion_rate_pct]],
      [__('Oldest open ticket'), oldest_open_text],
      ['Generated', "#{local(Time.current)} (#{timezone})"],
    ]
    rows.each_with_index do |(label, value), index|
      sheet.write(index + 2, 0, label, formats[:header])
      write_cell(sheet, index + 2, 1, value)
    end
  end

  def write_table(sheet, formats, headers, rows, keys)
    headers += [__('Average completion (days)')]
    sheet.set_column(0, 0, 32)
    sheet.set_column(1, headers.size - 1, 16)
    headers.each_with_index { |header, column| sheet.write(0, column, header, formats[:header]) }
    rows.each_with_index do |row, index|
      keys.each_with_index do |key, column|
        value = row[key]
        if !value.nil?
          key == :average_days ? sheet.write_number(index + 1, column, value, formats[:number]) : write_cell(sheet, index + 1, column, value)
        end
      end
    end
  end

  def write_repeats(sheet, formats)
    headers = ['Location', 'Category', 'Tickets', __('Still open'), __('Ticket numbers')]
    sheet.set_column(0, 1, 28)
    sheet.set_column(4, 4, 50)
    headers.each_with_index { |header, column| sheet.write(0, column, header, formats[:header]) }
    keys = %i[location category count still_open tickets]
    data[:repeats].each_with_index do |row, index|
      keys.each_with_index { |key, column| write_cell(sheet, index + 1, column, row[key]) }
    end
  end

  def write_tickets(sheet, formats) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    headers = ['Number', 'Title', 'Group', 'Category', 'Department', 'Location', 'Priority', 'State', 'Requester', 'Owner', 'Created', 'Completed', __('Days to complete')]
    headers.each_with_index { |header, column| sheet.write(0, column, header, formats[:header]) }
    sheet.set_column(1, 1, 40)
    sheet.set_column(2, 10, 18)
    tickets = (submitted + completed).uniq(&:id).sort_by(&:created_at)
    tickets.each_with_index do |ticket, index|
      values = [
        ticket.number, ticket.title, ticket.group&.name, category_name(ticket),
        (ticket.department if ticket.has_attribute?(:department)), (ticket.location if ticket.has_attribute?(:location)),
        ticket.priority&.name.to_s.sub(%r{\A\d+\s+}, ''), ticket.state&.name, ticket.customer&.fullname, owner_name(ticket),
        local(ticket.created_at), (local(ticket.close_at) if closed_state_ids.include?(ticket.state_id)),
        (days_to_complete(ticket) if closed_state_ids.include?(ticket.state_id))
      ]
      values.each_with_index { |value, column| write_cell(sheet, index + 1, column, value) if !value.nil? }
    end
  end

  # Text typed by users (titles, locations, names) is written as a literal string so a value like
  # "=HYPERLINK(...)" is never treated as a formula when the file is opened in Excel.
  def write_cell(sheet, row, column, value)
    return sheet.write_number(row, column, value) if value.is_a?(Numeric)

    sheet.write_string(row, column, value.to_s)
  end
end
