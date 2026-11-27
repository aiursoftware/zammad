# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: no departments (see Wcl::Setup.remove_departments).
class WclRemoveDepartments < ActiveRecord::Migration[7.2]
  def up
    drop_table :departments if table_exists?(:departments)

    # return if it's a new setup (the seeds run Wcl::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.remove_departments
  end
end
