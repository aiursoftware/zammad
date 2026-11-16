# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: everything the HR app integration needs in Zammad's data, in one place.
# Safe to run again; each step only adds what is missing. It runs
#
# - on a fresh install, from the seeds (db/seeds/wcl.rb),
# - on an existing install, from the HrPortalSetup migration,
# - by hand: `rails r 'HrPortal::Setup.run'` (or `rake zammad:wcl:setup`).
#
# Left to the admin: the other groups (tick "Customers can create tickets here"), agents,
# Microsoft 365 login, and later the HR app's API token.
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
    customers_no_state_on_create
    urgent_priority
    settings
    open_requests_overview
    ticket_category
    retire_maintenance_type
    ticket_location
    location_free_text
    without_hr_app
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

  DEPARTMENT_NOTE = __('Pick a department, or type a new one: it is added to the list for the next user. Admins can tidy the list in Admin > Objects > User > Department.')

  # The user's Department: a dropdown. Admins keep the list for now; the HR app fills it once
  # connected (see User::HrDepartments).
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
        note:       DEPARTMENT_NOTE,
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

  # Employees use Zammad itself for now; the HR app is connected later. Until then the Department
  # dropdown also takes a typed name (kept for reuse, see User::RemembersDepartment), and the HR
  # app's overview (empty without it) stays off. Once HR app tickets exist, both are left alone.
  def self.without_hr_app
    item = Tag::Item.find_by(name: 'hr-portal')
    return if item && Tag.exists?(tag_item_id: item.id)

    department_free_entry

    Overview.find_by(link: 'hr_portal_open')&.update!(active: false)
  end

  def self.department_free_entry
    department = ObjectManager::Attribute.get(object: 'User', name: 'department')
    return if !department

    data_option = department.data_option.merge('note' => DEPARTMENT_NOTE, 'unknown' => true)
    department.update!(data_option: data_option) if data_option != department.data_option
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
end
