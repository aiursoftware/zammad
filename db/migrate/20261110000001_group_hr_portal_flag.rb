# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: a "Show in HR app" switch on every group (see Group::HrPortalDefaults).
class GroupHrPortalFlag < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup
    return if !Setting.exists?(name: 'system_init_done')

    ObjectManager::Attribute.add(
      force:         true,
      object:        'Group',
      name:          'hr_portal',
      display:       'Show in HR app',
      data_type:     'boolean',
      data_option:   {
        null:       true,
        default:    true,
        note:       'Employees can pick this group as a category in the HR app, and every agent gets access to it. Switch off for teams tickets are only handed to (e.g. Dev, Network).',
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

    # Existing groups keep their current place: on only if customers may already pick them.
    Group.reset_column_information
    selectable = Array(Setting.get('customer_ticket_create_group_ids')).map(&:to_s)
    Group.find_each do |group|
      group.update_column(:hr_portal, selectable.include?(group.id.to_s)) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
