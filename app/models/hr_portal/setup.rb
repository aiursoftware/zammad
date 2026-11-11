# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: everything the HR app integration needs in Zammad's data, in one place.
# Safe to run again; each step only adds what is missing. It runs
#
# - on a fresh install, from the seeds (db/seeds/wcl.rb),
# - on an existing install, from the HrPortalSetup migration,
# - by hand: `rails r 'HrPortal::Setup.run'` (or `rake zammad:wcl:setup`).
#
# Left to the admin: the groups (tick "Customers can create tickets here"), agents, Microsoft
# 365 login, and later the HR app's API token.
module HrPortal::Setup # rubocop:disable Metrics/ModuleLength
  def self.run
    group_hr_portal_attribute
    group_hr_portal_label
    customer_priority
    ticket_assignees_attribute
    owners_core_workflow
    user_department_dropdown
    HrPortal::AttachmentRules.create_settings
    rejected_state
    customers_cannot_reject
    urgent_priority
    settings
    open_requests_overview
    true
  end

  # Employees file tickets in Zammad itself for now (the HR app comes later), so the switch says
  # what it does there.
  GROUP_FLAG_DISPLAY = __('Customers can create tickets here')
  GROUP_FLAG_NOTE    = __('Employees can pick this group when they create a ticket (and later in the HR app), and every agent gets access to it. Switch off for teams tickets are only handed to (e.g. Dev, Network).')

  # The customer-selectable switch on groups (attribute hr_portal, see Group::HrPortalDefaults).
  def self.group_hr_portal_attribute
    return if ObjectManager::Attribute.exists?(object_lookup_id: ObjectLookup.by_name('Group'), name: 'hr_portal')

    ObjectManager::Attribute.add(
      force:         true,
      object:        'Group',
      name:          'hr_portal',
      display:       GROUP_FLAG_DISPLAY,
      data_type:     'boolean',
      data_option:   {
        null:       true,
        default:    true,
        note:       GROUP_FLAG_NOTE,
        item_class: 'formGroup--halfSize',
        options:    { true => 'yes', false => 'no' },
        translate:  false,
      },
      editable:      true,
      active:        true,
      screens:       {
        create: { '-all-' => { null: true } },
        edit:   { '-all-' => { null: true } },
        view:   { '-all-' => { shown: true } },
      },
      to_create:     true,
      to_migrate:    false,
      to_delete:     false,
      position:      1500,
      created_by_id: 1,
      updated_by_id: 1,
    )
    ObjectManager::Attribute.migration_execute

    # Existing groups keep their place: on if customers may already pick them (a blank setting
    # means every group).
    Group.reset_column_information
    selectable = Array(Setting.get('customer_ticket_create_group_ids')).compact_blank.map(&:to_s)
    Group.find_each do |group|
      group.update_column(:hr_portal, selectable.empty? || selectable.include?(group.id.to_s)) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  # An install made while the switch was called "Show in HR app" gets the new wording.
  def self.group_hr_portal_label
    attribute = ObjectManager::Attribute.get(object: 'Group', name: 'hr_portal')
    return if !attribute || attribute.display == GROUP_FLAG_DISPLAY

    attribute.update!(display: GROUP_FLAG_DISPLAY, data_option: attribute.data_option.merge(note: GROUP_FLAG_NOTE))
  end

  # Employees choose how urgent their ticket is (low, normal, high, urgent) when they create it.
  def self.customer_priority
    attribute = ObjectManager::Attribute.get(object: 'Ticket', name: 'priority_id')
    return if !attribute || attribute.screens.dig('create_middle', 'ticket.customer')

    screens = attribute.screens.deep_dup
    screens['create_middle'] ||= {}
    screens['create_middle']['ticket.customer'] = { 'null' => false, 'item_class' => 'column' }
    attribute.update!(screens: screens)
  end

  # "Owners" on tickets (see Ticket::Assignees).
  def self.ticket_assignees_attribute
    return if ObjectManager::Attribute.get(object: 'Ticket', name: 'assignees')

    ObjectManager::Attribute.add(
      force:         true,
      object:        'Ticket',
      name:          'assignees',
      display:       'Owners',
      # the searchable picker with tokens (a plain multiselect is a Ctrl+click list box)
      data_type:     'multi_tree_select',
      data_option:   {
        options:    User::AssigneeOptions.options,
        default:    [],
        null:       true,
        multiple:   true,
        translate:  false,
        nulloption: true,
        maxlength:  255,
        note:       __('Everyone working on the ticket. The first is its main owner ("My Assigned Tickets"); all of them are notified, and the others find it under "My Subscribed Tickets".'),
        permission: ['ticket.agent'],
      },
      editable:      true,
      active:        true,
      screens:       {
        create_middle: { 'ticket.agent' => { null: true, item_class: 'column' } },
        edit:          { 'ticket.agent' => { null: true } },
      },
      to_create:     true,
      to_migrate:    false,
      to_delete:     false,
      position:      30,
      created_by_id: 1,
      updated_by_id: 1,
    )
    ObjectManager::Attribute.migration_execute
    Ticket.reset_column_information
  end

  # "Owners" takes the place of the single "Owner" field on the ticket screens; the owner is
  # still kept, set from the first of the owners.
  def self.owners_core_workflow
    CoreWorkflow.create_if_not_exists(
      name:               'WCL: Owners instead of Owner',
      object:             'Ticket',
      condition_saved:    {},
      condition_selected: {},
      perform:            { 'ticket.owner_id' => { 'operator' => 'hide', 'hide' => 'true' } },
      active:             true,
      stop_after_match:   false,
      changeable:         true,
      priority:           500,
      created_by_id:      1,
      updated_by_id:      1,
    )
  end

  # The user's Department: a dropdown the HR app fills (see User::HrDepartments).
  def self.user_department_dropdown
    attribute = ObjectManager::Attribute.get(object: 'User', name: 'department')
    return if !attribute || attribute.data_type == 'tree_select'

    # Departments people already have stay pickable until the HR app sends its list.
    names   = User.where.not(department: [nil, '']).distinct.pluck(:department).sort_by(&:downcase)
    options = names.map { |name| { 'value' => name, 'name' => name } }

    # The column stays a string; only the way it is edited changes.
    attribute.update!(
      data_type:   'tree_select',
      data_option: {
        options:    options,
        default:    '',
        null:       true,
        nulloption: true,
        multiple:   false,
        translate:  false,
        maxlength:  200,
        item_class: 'formGroup--halfSize',
        note:       __('Managed in the HR app (Departments); the list here follows it.'),
      },
    )
  end

  # A closed state the HR app shows as "Rejected".
  def self.rejected_state
    Ticket::State.create_if_not_exists(
      name:              'rejected',
      state_type:        Ticket::StateType.find_by!(name: 'closed'),
      active:            true,
      ignore_escalation: true,
      default_create:    false,
      default_follow_up: false,
      note:              __('Request turned down (WCL). Shown to the employee as "Rejected" in the HR app.'),
      created_by_id:     1,
      updated_by_id:     1,
    )

    # Which states each screen offers is stored on the State field. Zammad refreshes it when a state
    # changes, but not before the system is set up, so on a fresh install (seeds) do it here.
    Ticket::State.update_state_field_configuration
  end

  # Only agents reject a request: the state is left out of the customer's state list (new ticket
  # and ticket view). A ticket already rejected still shows its state to the customer.
  def self.customers_cannot_reject
    rejected = Ticket::State.find_by(name: 'rejected')
    agent    = Permission.find_by(name: 'ticket.agent')
    return if !rejected || !agent

    CoreWorkflow.create_if_not_exists(
      name:               'WCL: Customers cannot set Rejected',
      object:             'Ticket',
      condition_saved:    {},
      condition_selected: { 'session.permission_ids' => { 'operator' => 'is not', 'value' => [agent.id.to_s] } },
      perform:            { 'ticket.state_id' => { 'operator' => 'remove_option', 'remove_option' => [rejected.id.to_s] } },
      active:             true,
      stop_after_match:   false,
      changeable:         true,
      priority:           510,
      created_by_id:      1,
      updated_by_id:      1,
    )
  end

  # "4 urgent", above high, with its own colour (see the urgent-priority styles).
  def self.urgent_priority
    priority = Ticket::Priority.find_by(name: '4 urgent') || Ticket::Priority.new(name: '4 urgent')
    priority.update!(ui_icon: 'important', ui_color: 'urgent-priority', active: true, created_by_id: 1, updated_by_id: 1)
  end

  def self.settings
    Setting.set('ui_ticket_priority_icons', true)

    # 30 days without activity before a session ends.
    month = 30.days.to_i.to_s
    timeout = Setting.get('session_timeout')
    Setting.set('session_timeout', timeout.transform_values { month }) if timeout.is_a?(Hash)
  end

  # Every open HR-portal ticket, for agents; the HR app adds one per department.
  def self.open_requests_overview
    return if Overview.exists?(link: 'hr_portal_open')

    columns = %w[number title customer group state updated_at]
    states  = Ticket::State.where(name: ['new', 'open', 'pending reminder']).pluck(:id)
    Overview.create!(
      name:            __('HR portal – open requests'),
      link:            'hr_portal_open',
      prio:            1300,
      role_ids:        Role.with_permissions('ticket.agent').pluck(:id),
      condition:       {
        'ticket.state_id' => { 'operator' => 'is', 'value' => states },
        'ticket.tags'     => { 'operator' => 'contains all', 'value' => 'hr-portal' },
      },
      order:           { by: 'updated_at', direction: 'DESC' },
      view:            { d: columns, s: columns, m: columns, view_mode_default: 's' },
      group_by:        'group',
      group_direction: 'ASC',
      active:          true,
      created_by_id:   1,
      updated_by_id:   1,
    )
  end
end
