# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the Department on users and tickets is a dropdown of Admin > Manage >
# Departments (see Wcl::Setup.department_dropdown).
class WclDepartmentDropdown < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run Wcl::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.department_dropdown
  end
end
