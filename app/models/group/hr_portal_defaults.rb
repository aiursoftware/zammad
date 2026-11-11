# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the "Show in HR app" switch on a group (attribute `hr_portal`, added by
# the GroupHrPortalFlag migration) is the one place to decide whether employees can file into it.
#
# - The switch drives Zammad's "Customer selectable groups" setting, which the HR app reads
#   its categories from. Change it on the group, not in the setting.
# - A new group with the switch on also gives the agent role(s) full access, so every agent sees
#   and answers its tickets without further setup.
#
# Imports and the initial seed are left alone.
module Group::HrPortalDefaults
  extend ActiveSupport::Concern

  # Zammad reads an empty "Customer selectable groups" setting as "every group". When no group
  # is switched on, this id (which no group has) keeps the list empty instead.
  NO_GROUP = '0'.freeze

  included do
    after_create  :hr_portal_give_agents_access
    after_save    :hr_portal_sync_customer_groups
    after_destroy :hr_portal_sync_customer_groups
  end

  private

  def hr_portal_enabled?
    return false if !has_attribute?(:hr_portal)
    return false if Setting.get('import_mode')

    Setting.get('system_init_done').present?
  end

  def hr_portal_sync_customer_groups
    return if !hr_portal_enabled?
    # A new group keeping the column default ("yes") counts as no change, so creation always syncs.
    return if !destroyed? && !previously_new_record? && !saved_change_to_hr_portal?

    ids = Group.where(hr_portal: true).reorder(:id).pluck(:id).map(&:to_s)
    Setting.set('customer_ticket_create_group_ids', ids.presence || [NO_GROUP])
  end

  def hr_portal_give_agents_access
    return if !hr_portal_enabled?
    return if !hr_portal

    # Every role that answers tickets, whatever it is called ("Agent" by default).
    Role.with_permissions('ticket.agent').each do |role|
      next if RoleGroup.exists?(role_id: role.id, group_id: id, access: 'full')

      RoleGroup.create!(role_id: role.id, group_id: id, access: 'full')
    end
  end
end
