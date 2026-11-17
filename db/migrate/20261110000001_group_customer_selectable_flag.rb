# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: a "Show in HR app" switch on every group (see Group::HrPortalDefaults).
class GroupHrPortalFlag < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run HrPortal::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    HrPortal::Setup.group_hr_portal_attribute
  end
end
