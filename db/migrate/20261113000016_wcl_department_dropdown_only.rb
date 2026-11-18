# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the Department dropdown no longer takes typed names on installs that had the
# earlier "dropdown with typing" version (see Wcl::Setup.department_dropdown_field).
class WclDepartmentDropdownOnly < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run Wcl::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.department_dropdown
  end
end
