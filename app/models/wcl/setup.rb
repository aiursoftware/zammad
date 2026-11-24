# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: everything the HR app integration needs in Zammad's data, in one place.
# Safe to run again; each step only adds what is missing. It runs
#
# - on a fresh install, from the seeds (db/seeds/wcl.rb),
# - on an existing install, from the WclSetup migration,
# - by hand: `rails r 'Wcl::Setup.run'` (or `rake zammad:wcl:setup`).
#
# Left to the admin: the other groups (tick "Customers can create tickets here"), agents,
# Microsoft 365 login, and later the HR app's API token.
module Wcl::Setup # rubocop:disable Metrics/ModuleLength
  def self.run
    group_customer_selectable_attribute
    group_customer_selectable_label
    customer_priority
    ticket_assignees_attribute
    owners_core_workflow
    department_dropdown
    Wcl::AttachmentRules.create_settings
    rejected_state
    customers_cannot_reject
    customers_no_state_on_create
    urgent_priority
    settings
    open_requests_overview
    ticket_category
    retire_maintenance_type
    ticket_location
    location_free_text
    without_hr_app
    manager_role
    work_states
    ticket_department
    manager_summary
    activity_stream_retention
    default_group
    ticket_target_date
    email_only_existing_users
    true
  end

  # Employees file tickets in Zammad itself for now (the HR app comes later), so the switch says
  # what it does there.
  GROUP_FLAG_DISPLAY = __('Customers can create tickets here')
  GROUP_FLAG_NOTE    = __('Employees can pick this group when they create a ticket (and later in the HR app). Switch off for teams tickets are only handed to (e.g. Dev, Network).')

  # The customer-selectable switch on groups (attribute hr_portal, see Group::CustomerSelectable).
  def self.group_customer_selectable_attribute
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
  def self.group_customer_selectable_label
    attribute = ObjectManager::Attribute.get(object: 'Group', name: 'hr_portal')
    return if !attribute || (attribute.display == GROUP_FLAG_DISPLAY && attribute.data_option.with_indifferent_access[:note] == GROUP_FLAG_NOTE)

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

  DEPARTMENT_NOTE        = __('Pick the department. The list is managed in Admin > Manage > Departments.')
  TICKET_DEPARTMENT_NOTE = __('Department of the requester when the ticket was created; filled in automatically.')

  # The user's Department (and the ticket's): a dropdown of the active departments of Admin >
  # Manage > Departments; no new names are typed here, and nothing is synced with the HR app.
  # Also turns the earlier text field / dropdown into this one; the values are kept.
  def self.department_dropdown
    Department::DROPDOWNS.each { |object, name| department_dropdown_field(object, name) }
    Department.refresh_dropdowns
  end

  # Settings from earlier versions of the field: free typing (unknown), the HR app sync, suggestions.
  RETIRED_DEPARTMENT_OPTIONS = %w[unknown hr_departments suggestions].freeze

  def self.department_dropdown_field(object, name)
    attribute = ObjectManager::Attribute.get(object: object, name: name)
    return if !attribute

    if attribute.data_type == 'tree_select'
      retired = attribute.data_option.to_h.stringify_keys.keys & RETIRED_DEPARTMENT_OPTIONS
      return if retired.empty?

      # No new names typed into the dropdown: only Admin > Manage > Departments adds them.
      attribute.update_columns(data_option: attribute.data_option.to_h.stringify_keys.except(*retired), updated_at: Time.zone.now) # rubocop:disable Rails/SkipsModelValidations
      return
    end

    # The column stays a string; only the way it is edited changes.
    attribute.update_columns( # rubocop:disable Rails/SkipsModelValidations
      data_type:   'tree_select',
      data_option: department_data_option(object == 'User' ? DEPARTMENT_NOTE : TICKET_DEPARTMENT_NOTE, half: object == 'User'),
      updated_at:  Time.zone.now,
    )
  end

  def self.department_data_option(note, half: false)
    {
      'options'    => Department.options,
      'default'    => '',
      'null'       => true,
      'nulloption' => true,
      'multiple'   => false,
      'translate'  => false,
      'maxlength'  => 200,
      'note'       => note,
      **(half ? { 'item_class' => 'formGroup--halfSize' } : {}),
    }
  end

  # Older migrations call it by its earlier names.
  def self.department_text_field
    department_dropdown
  end

  def self.user_department_dropdown
    department_dropdown
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

  # A new ticket from an employee always starts as "new"; the State field on their create form
  # only offered "new" or "closed", so it is hidden there. They still see the state on the ticket.
  def self.customers_no_state_on_create
    agent = Permission.find_by(name: 'ticket.agent')
    return if !agent

    CoreWorkflow.create_if_not_exists(
      name:               'WCL: Customers do not pick the state of a new ticket',
      object:             'Ticket',
      preferences:        { 'screen' => ['create_middle'] },
      condition_saved:    {},
      condition_selected: { 'session.permission_ids' => { 'operator' => 'is not', 'value' => [agent.id.to_s] } },
      perform:            { 'ticket.state_id' => { 'operator' => 'hide', 'hide' => 'true' } },
      active:             true,
      stop_after_match:   false,
      changeable:         true,
      priority:           511,
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
      # Only tickets filed through the HR app are tagged; switched on when the HR app is connected.
      active:          false,
      created_by_id:   1,
      updated_by_id:   1,
    )
  end

  MAINTENANCE_GROUP = 'Maintenance'.freeze
  MAINTENANCE_CATEGORIES = [
    __('Warehouse maintenance'),
    __('Trucking / vehicle maintenance'),
    __('Office maintenance'),
    __('General facility repairs'),
    'Other',
  ].freeze

  # "Category" on tickets, listed by group: in Admin > Objects > Ticket > Category the first level
  # is a group's name and the entries under it are that group's categories. The ticket form only
  # offers the chosen group's categories (required when it has any, hidden when it has none), see
  # CoreWorkflow::Custom::WclTicketCategory. Starts with a Maintenance group and its categories.
  def self.ticket_category
    Group.find_by(name: MAINTENANCE_GROUP) || Group.create!(
      name: MAINTENANCE_GROUP, active: true, follow_up_possible: 'yes', created_by_id: 1, updated_by_id: 1
    )
    ticket_category_attribute
    category_flat_list
    Group::RenamesTicketCategories.add_category_entries(Group.where(active: true))
    CoreWorkflow.create_if_not_exists(
      name:               'WCL: Category follows the group',
      object:             'Ticket',
      condition_saved:    {},
      condition_selected: {},
      perform:            { 'custom.module' => { 'execute' => ['CoreWorkflow::Custom::WclTicketCategory'] } },
      active:             true,
      stop_after_match:   false,
      changeable:         false,
      priority:           520,
      created_by_id:      1,
      updated_by_id:      1,
    )
  end

  def self.ticket_category_attribute
    return if ObjectManager::Attribute.get(object: 'Ticket', name: 'category')

    maintenance = {
      'name'     => MAINTENANCE_GROUP,
      'value'    => MAINTENANCE_GROUP,
      'children' => MAINTENANCE_CATEGORIES.map { |name| { 'name' => name, 'value' => "#{MAINTENANCE_GROUP}::#{name}" } },
    }
    ObjectManager::Attribute.add(
      force:         true,
      object:        'Ticket',
      name:          'category',
      display:       __('Category'),
      data_type:     'tree_select',
      data_option:   {
        options:               [maintenance],
        # the form lists only the chosen group's categories, so show them without the group level
        flatten_single_branch: true,
        default:               '',
        null:                  true,
        nulloption:            true,
        multiple:              false,
        translate:             false,
        maxlength:             255,
        note:                  __('First level: the name of a group. Under it: the categories offered for that group.'),
      },
      editable:      true,
      active:        true,
      screens:       {
        create_middle: {
          'ticket.customer' => { shown: true, required: false, item_class: 'column' },
          'ticket.agent'    => { shown: true, required: false, item_class: 'column' },
        },
        edit:          {
          'ticket.customer' => { shown: true, required: false },
          'ticket.agent'    => { shown: true, required: false },
        },
      },
      to_create:     true,
      to_migrate:    false,
      to_delete:     false,
      position:      35,
      created_by_id: 1,
      updated_by_id: 1,
    )
    ObjectManager::Attribute.migration_execute
    Ticket.reset_column_information
  end

  LOCATION_DATA_OPTION = {
    'type'      => 'text',
    'maxlength' => 255,
    'null'      => true,
    'default'   => '',
    'note'      => __('Where is it? e.g. Warehouse A, Office 2nd floor, Truck 51C-12345'),
  }.freeze

  # shown/required: the format Admin > Objects saves, so editing the field there keeps it required.
  LOCATION_SCREENS = {
    'create_middle' => {
      'ticket.customer' => { 'shown' => true, 'required' => true, 'item_class' => 'column' },
      'ticket.agent'    => { 'shown' => true, 'required' => true, 'item_class' => 'column' },
    },
    'edit'          => {
      'ticket.customer' => { 'shown' => true, 'required' => false },
      'ticket.agent'    => { 'shown' => true, 'required' => false },
    },
  }.freeze

  # Where the request is about, typed freely; required on every new ticket.
  def self.ticket_location
    return if ObjectManager::Attribute.get(object: 'Ticket', name: 'location')

    ObjectManager::Attribute.add(
      force:         true,
      object:        'Ticket',
      name:          'location',
      display:       __('Location'),
      data_type:     'input',
      data_option:   LOCATION_DATA_OPTION.dup,
      editable:      true,
      active:        true,
      screens:       LOCATION_SCREENS.deep_dup,
      to_create:     true,
      to_migrate:    false,
      to_delete:     false,
      position:      34,
      created_by_id: 1,
      updated_by_id: 1,
    )
    ObjectManager::Attribute.migration_execute
    Ticket.reset_column_information
  end

  # An install that got Location as a dropdown: it becomes free text (same column), and tickets
  # keep the location's name instead of the option's key.
  def self.location_free_text
    attribute = ObjectManager::Attribute.get(object: 'Ticket', name: 'location')
    return if !attribute || attribute.data_type == 'input'

    names = option_names(attribute)
    names.each do |key, name|
      next if name.blank? || name.to_s == key

      Ticket.where(location: key).update_all(location: name.to_s) # rubocop:disable Rails/SkipsModelValidations
    end

    attribute.update_columns( # rubocop:disable Rails/SkipsModelValidations
      data_type:   'input',
      data_option: LOCATION_DATA_OPTION.dup,
      screens:     LOCATION_SCREENS.deep_dup,
      updated_at:  Time.zone.now,
    )
  end

  # An install that got the earlier "Maintenance type" field: its values move into Category
  # ("Maintenance::<type>") and the field and its rules are removed.
  def self.retire_maintenance_type
    attribute = ObjectManager::Attribute.get(object: 'Ticket', name: 'maintenance_type')
    return if !attribute

    # the keys the field was created with, in case its options were edited since
    names = { 'warehouse' => __('Warehouse maintenance'), 'vehicle' => __('Trucking / vehicle maintenance'),
              'office' => __('Office maintenance'), 'facility' => __('General facility repairs'), 'other' => 'Other' }
      .merge(option_names(attribute).compact_blank)
    Ticket.where.not(maintenance_type: [nil, '']).find_each do |ticket|
      next if ticket.category.present?

      name = names[ticket.maintenance_type.to_s].presence || ticket.maintenance_type
      ticket.update_columns(category: "#{MAINTENANCE_GROUP}::#{name}") # rubocop:disable Rails/SkipsModelValidations
    end

    CoreWorkflow.where(name: ['WCL: Maintenance type hidden', 'WCL: Maintenance type for Maintenance tickets']).destroy_all
    ObjectManager::Attribute.remove(object: 'Ticket', name: 'maintenance_type')
    ObjectManager::Attribute.migration_execute
    Ticket.reset_column_information
  end

  # Employees use Zammad itself for now; the HR app is connected later. Until then the HR app's
  # overview (empty without it) stays off. Once HR app tickets exist, it is left alone.
  def self.without_hr_app
    item = Tag::Item.find_by(name: 'hr-portal')
    return if item && Tag.exists?(tag_item_id: item.id)

    Overview.find_by(link: 'hr_portal_open')&.update!(active: false)
  end

  # Older migrations call it by its earlier name.
  def self.department_free_entry
    department_text_field
  end

  # { key => name } of a select's options, stored as a hash or (after editing in Admin > Objects)
  # as a list of { value:, name: }.
  def self.option_names(attribute)
    options = attribute.data_option['options']
    return options.to_h { |key, name| [key.to_s, name.to_s] } if options.is_a?(Hash)

    Array(options).to_h { |option| [option['value'].to_s, option['name'].to_s] }
  end

  # Installs whose Category was created before the form showed the group's categories directly.
  def self.category_flat_list
    attribute = ObjectManager::Attribute.get(object: 'Ticket', name: 'category')
    return if !attribute || attribute.data_option['flatten_single_branch']

    attribute.update!(data_option: attribute.data_option.merge('flatten_single_branch' => true))
  end

  MANAGER_ROLE = 'Manager'.freeze

  # A "Manager" role that tracks the agents' work: Reporting and overviews of each agent's open and
  # recently closed tickets. The role itself grants no group: each manager gets the groups they
  # oversee on their user (Admin > Users > the user > Group permissions: Read, Overview, Change),
  # and sees only those groups' tickets, in the overviews, search and Reporting alike. Users whose
  # only agent role is Manager aren't offered as owners (User::AssigneeOptions).
  def self.manager_role
    role = Role.find_by(name: MANAGER_ROLE) || Role.create!(
      name:              MANAGER_ROLE,
      note:              __('Tracks the work of the agents in the groups set on each manager (Admin > Users > Group permissions: Read, Overview, Change): Reporting and the "Team" overviews. Not offered as an owner unless the user is also an Agent.'),
      permissions:       Permission.where(name: %w[ticket.agent report user_preferences]),
      active:            true,
      default_at_signup: false,
      created_by_id:     1,
      updated_by_id:     1,
    )
    manager_overviews(role)
    User::AssigneeOptions.refresh
  end

  def self.manager_overviews(role)
    open    = Ticket::State.by_category_ids(:work_on_all)
    closed  = Ticket::State.where(state_type: Ticket::StateType.where(name: 'closed')).pluck(:id)
    columns = %w[number title customer department group owner state priority updated_at]

    {
      'wcl_team_open'       => [__('Team: open tickets by agent'), 1200,
                                { 'ticket.state_id' => { 'operator' => 'is', 'value' => open } },
                                { by: 'updated_at', direction: 'DESC' }, 'owner'],
      'wcl_team_unassigned' => [__('Team: unassigned tickets'), 1210,
                                { 'ticket.state_id' => { 'operator' => 'is', 'value' => open },
                                  'ticket.owner_id' => { 'operator' => 'is', 'pre_condition' => 'not_set' } },
                                { by: 'created_at', direction: 'ASC' }, 'group'],
      'wcl_team_stale'      => [__('Team: no update for 3 days'), 1220,
                                { 'ticket.state_id'   => { 'operator' => 'is', 'value' => open },
                                  'ticket.updated_at' => { 'operator' => 'before (relative)', 'value' => 3, 'range' => 'day' } },
                                { by: 'updated_at', direction: 'ASC' }, 'owner'],
      'wcl_team_closed'     => [__('Team: closed in the last 7 days'), 1230,
                                { 'ticket.state_id' => { 'operator' => 'is', 'value' => closed },
                                  'ticket.close_at' => { 'operator' => 'within last (relative)', 'value' => 7, 'range' => 'day' } },
                                { by: 'close_at', direction: 'DESC' }, 'owner'],
    }.each do |link, (name, prio, condition, order, group_by)|
      next if Overview.exists?(link: link)

      Overview.create!(
        name: name, link: link, prio: prio, role_ids: [role.id], condition: condition, order: order,
        view: { d: columns, s: columns, m: columns, view_mode_default: 's' },
        group_by: group_by, group_direction: 'ASC', active: true, created_by_id: 1, updated_by_id: 1
      )
    end
  end

  # Work states between open and closed, for agents: "in progress" (being worked on) and "on hold"
  # (waiting, e.g. for parts; no escalation while on hold). Both are open states, so they count
  # as open work everywhere; Completed is the existing "closed".
  WORK_STATES = {
    'in progress' => [false, __('Being worked on (WCL).')],
    'on hold'     => [true,  __('Waiting, e.g. for parts or a supplier; does not escalate (WCL).')],
  }.freeze

  def self.work_states
    open_type = Ticket::StateType.find_by!(name: 'open')
    WORK_STATES.each do |name, (ignore_escalation, note)|
      next if Ticket::State.exists?(name: name)

      Ticket::State.create!(
        name: name, state_type: open_type, active: true, ignore_escalation: ignore_escalation,
        default_create: false, default_follow_up: false, note: note, created_by_id: 1, updated_by_id: 1
      )
    end
    Ticket::State.update_state_field_configuration

    ids = Ticket::State.where(name: WORK_STATES.keys).pluck(:id)
    work_states_in_open_overviews(ids)
    customers_cannot_set_work_states(ids)
  end

  # Overviews keep the state ids they list: every overview listing "open" tickets also lists the
  # work states, so tickets in progress or on hold don't drop out of "Open", "My assigned", ...
  def self.work_states_in_open_overviews(ids)
    open = Ticket::State.find_by(name: 'open')&.id.to_s
    Overview.find_each do |overview|
      condition = overview.condition.deep_dup
      rule      = condition['ticket.state_id']
      next if !rule.is_a?(Hash) || rule['operator'] != 'is'

      values = Array(rule['value']).map(&:to_s)
      next if values.exclude?(open)

      missing = ids.map(&:to_s) - values
      next if missing.empty?

      rule['value'] = Array(rule['value']) + missing.map { |id| rule['value'].first.is_a?(Integer) ? id.to_i : id }
      overview.update!(condition: condition)
    end
  end

  # Like Rejected, only agents move a ticket to In Progress or On Hold.
  def self.customers_cannot_set_work_states(ids)
    agent = Permission.find_by(name: 'ticket.agent')
    return if !agent || ids.empty?

    CoreWorkflow.create_if_not_exists(
      name:               'WCL: Customers cannot set In Progress or On Hold',
      object:             'Ticket',
      condition_saved:    {},
      condition_selected: { 'session.permission_ids' => { 'operator' => 'is not', 'value' => [agent.id.to_s] } },
      perform:            { 'ticket.state_id' => { 'operator' => 'remove_option', 'remove_option' => ids.map(&:to_s) } },
      active:             true,
      stop_after_match:   false,
      changeable:         true,
      priority:           512,
      created_by_id:      1,
      updated_by_id:      1,
    )
  end

  # The requester's department, stored on the ticket (Ticket::StampsDepartment). Agents see and
  # can correct it; it isn't on the new-ticket form, as it comes from the employee's profile.
  def self.ticket_department
    ticket_department_attribute
    ticket_department_backfill
    ticket_department_in_team_overviews
  end

  def self.ticket_department_attribute
    return if ObjectManager::Attribute.get(object: 'Ticket', name: 'department')

    ObjectManager::Attribute.add(
      force:         true,
      object:        'Ticket',
      name:          'department',
      display:       __('Department'),
      data_type:     'tree_select',
      data_option:   department_data_option(TICKET_DEPARTMENT_NOTE),
      editable:      true,
      active:        true,
      screens:       {
        create_middle: {
          'ticket.customer' => { 'shown' => false, 'required' => false },
          'ticket.agent'    => { 'shown' => false, 'required' => false },
        },
        edit:          { 'ticket.agent' => { 'shown' => true, 'required' => false } },
      },
      to_create:     true,
      to_migrate:    false,
      to_delete:     false,
      position:      33,
      created_by_id: 1,
      updated_by_id: 1,
    )
    ObjectManager::Attribute.migration_execute
    Ticket.reset_column_information
  end

  # Tickets from before the field existed get their requester's current department.
  def self.ticket_department_backfill
    return if Ticket.column_names.exclude?('department')

    Ticket.where(department: [nil, '']).includes(:customer).find_each do |ticket|
      department = ticket.customer&.department.presence
      next if !department

      ticket.update_columns(department: department) # rubocop:disable Rails/SkipsModelValidations
      SearchIndexJob.perform_later('Ticket', ticket.id)
    end
  end

  # Managers see each ticket's department in their Team overviews.
  def self.ticket_department_in_team_overviews
    Overview.where(link: %w[wcl_team_open wcl_team_unassigned wcl_team_stale wcl_team_closed]).find_each do |overview|
      view = overview.view.to_h.deep_stringify_keys
      changed = false
      %w[d s m].each do |mode|
        columns = Array(view[mode]).dup
        next if columns.empty? || columns.include?('department')

        index = columns.index('customer')
        columns.insert(index ? index + 1 : columns.size, 'department')
        view[mode] = columns
        changed = true
      end
      overview.update!(view: view) if changed
    end
  end

  # Admin > Manage > Departments starts with the departments people already have. Run once, when
  # the list is created (CreateDepartments), so a department deleted later stays deleted.
  def self.departments
    return if !Department.table_exists?

    names = User.where.not(department: [nil, '']).distinct.pluck(:department).map { |name| name.strip.squeeze(' ') }
    known = Department.pluck(:name).map(&:downcase)
    names.compact_blank.uniq(&:downcase).each do |name|
      next if known.include?(name.downcase)

      Department.create!(name: name, active: true, created_by_id: 1, updated_by_id: 1)
    end
    Department.refresh_dropdowns
  end

  # The weekly summary email to managers (Wcl::ManagerSummary): a switch in Admin > Settings >
  # Ticket > Base, and a scheduler job that sends it on Monday at 07:00 (system time zone).
  def self.manager_summary
    Setting.create_if_not_exists(
      title:       __('Weekly summary email to managers'),
      name:        Wcl::ManagerSummary::SETTING,
      area:        'Ticket::Base',
      description: __("Every Monday at 07:00, send each user with the Manager role a summary of last week's tickets for their groups, with the Excel report attached."),
      options:     { form: [{ display: '', null: true, name: Wcl::ManagerSummary::SETTING, tag: 'boolean', options: { true => 'yes', false => 'no' } }] },
      preferences: { prio: 2000, permission: ['admin.ticket'] },
      state:       true,
      frontend:    false,
    )

    scheduler = Scheduler.find_or_initialize_by(method: 'Wcl::ManagerSummary.deliver_all')
    scheduler.update!(
      name:          'WCL: weekly summary to managers',
      period:        1.hour,
      prio:          3,
      active:        true,
      timeplan:      { 'days' => { 'Mon' => true }, 'hours' => { '7' => true }, 'minutes' => { '0' => true } },
      updated_by_id: 1,
      created_by_id: scheduler.created_by_id || 1,
    )
  end

  DEFAULT_GROUP_NOTE = __('New tickets start in this group (for everyone who may create tickets in it). Only one group can be the default.')

  # "Default for new tickets" on groups and the form rule that preselects it
  #   (see Group::DefaultForNewTickets and CoreWorkflow::Custom::WclDefaultGroup).
  def self.default_group
    if !ObjectManager::Attribute.exists?(object_lookup_id: ObjectLookup.by_name('Group'), name: Group::DefaultForNewTickets::ATTRIBUTE)
      ObjectManager::Attribute.add(
        force:         true,
        object:        'Group',
        name:          Group::DefaultForNewTickets::ATTRIBUTE,
        display:       __('Default for new tickets'),
        data_type:     'boolean',
        data_option:   {
          null:       true,
          default:    false,
          note:       DEFAULT_GROUP_NOTE,
          item_class: 'formGroup--halfSize',
          options:    { true => 'yes', false => 'no' },
          translate:  true,
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
        position:      1510,
        created_by_id: 1,
        updated_by_id: 1,
      )
      ObjectManager::Attribute.migration_execute
      Group.reset_column_information
    end

    CoreWorkflow.create_if_not_exists(
      name:               'WCL: New tickets start in the default group',
      object:             'Ticket',
      condition_saved:    {},
      condition_selected: {},
      perform:            { 'custom.module' => { 'execute' => ['CoreWorkflow::Custom::WclDefaultGroup'] } },
      active:             true,
      stop_after_match:   false,
      changeable:         false,
      priority:           510,
      created_by_id:      1,
      updated_by_id:      1,
    )
  end

  # How long the dashboard Activity Stream keeps its entries (Admin > Dashboard > "Keep activities
  #   for"); the daily "Delete old activity stream entries." job reads it (see ActivityStream.cleanup).
  def self.activity_stream_retention
    Setting.create_if_not_exists(
      title:       __('Keep activities for'),
      name:        ActivityStream::RETENTION_SETTING,
      area:        'Dashboard::Base',
      description: __('Number of days the activity stream keeps its entries. Older entries are deleted once a day.'),
      options:     {},
      preferences: { authentication: true, permission: ['admin.dashboard'] },
      state:       90,
      frontend:    true,
    )
  end

  # When the requester needs the work done by; optional, set on the new-ticket form by whoever
  #   creates the ticket (employee or agent), and changeable later in the ticket sidebar.
  def self.ticket_target_date
    return if ObjectManager::Attribute.get(object: 'Ticket', name: 'target_date')

    ObjectManager::Attribute.add(
      force:         true,
      object:        'Ticket',
      name:          'target_date',
      display:       __('Target date'),
      data_type:     'date',
      data_option:   { diff: nil, null: true, note: __('When this needs to be done by (optional).') },
      editable:      true,
      active:        true,
      screens:       {
        create_middle: {
          'ticket.customer' => { 'shown' => true, 'required' => false, 'item_class' => 'column' },
          'ticket.agent'    => { 'shown' => true, 'required' => false, 'item_class' => 'column' },
        },
        edit:          {
          'ticket.customer' => { 'shown' => true, 'required' => false },
          'ticket.agent'    => { 'shown' => true, 'required' => false },
        },
      },
      to_create:     true,
      to_migrate:    false,
      to_delete:     false,
      position:      35,
      created_by_id: 1,
      updated_by_id: 1,
    )
    ObjectManager::Attribute.migration_execute
    Ticket.reset_column_information
  end

  # Admin > Channels > Email > Settings > "Accept email only from existing users", and the
  #   postmaster filter that drops the rest (see Wcl::UnknownEmailSenders). Off by default so the
  #   stock email specs keep working; the WclEmailOnlyExistingUsers migration switches it on.
  def self.email_only_existing_users
    Setting.create_if_not_exists(
      title:       __('Accept email only from existing users'),
      name:        Wcl::UnknownEmailSenders::SETTING,
      area:        'Email::Base',
      description: __('Email from senders without a user account is dropped, and addresses in To/Cc are not added as users. Create the user first to let them email in.'),
      options:     {
        form: [
          {
            display: '',
            null:    true,
            name:    Wcl::UnknownEmailSenders::SETTING,
            tag:     'boolean',
            options: { true => 'yes', false => 'no' },
          },
        ],
      },
      state:       false,
      preferences: {
        permission: ['admin.channel_email', 'admin.channel_google', 'admin.channel_microsoft365', 'admin.channel_microsoft_graph'],
      },
      frontend:    false,
    )
    Setting.create_if_not_exists(
      title:       __('Blocked email addresses'),
      name:        Wcl::UnknownEmailSenders::BLOCKED_SETTING,
      area:        'Email::Base',
      description: __('Email from these addresses is always dropped, one address per line. Deleting a user can add their address here; remove a line to unblock it.'),
      options:     {
        form: [
          {
            display: '',
            null:    true,
            name:    Wcl::UnknownEmailSenders::BLOCKED_SETTING,
            tag:     'textarea',
          },
        ],
      },
      state:       '',
      preferences: {
        permission: ['admin.channel_email', 'admin.channel_google', 'admin.channel_microsoft365', 'admin.channel_microsoft_graph'],
      },
      frontend:    false,
    )
    Setting.create_if_not_exists(
      title:       __('Defines postmaster filter.'),
      name:        Wcl::UnknownEmailSenders::FILTER,
      area:        'Postmaster::PreFilter',
      description: __('Defines postmaster filter to drop email from senders without a user account.'),
      options:     {},
      state:       'Channel::Filter::WclBlockUnknownSenders',
      frontend:    false,
    )
  end
end
