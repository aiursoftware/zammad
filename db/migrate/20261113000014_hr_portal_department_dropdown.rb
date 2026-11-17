# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the Department on users and tickets is a dropdown of Admin > Manage >
# Departments (see HrPortal::Setup.department_dropdown).
class HrPortalDepartmentDropdown < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run HrPortal::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    HrPortal::Setup.department_dropdown
  end
end
