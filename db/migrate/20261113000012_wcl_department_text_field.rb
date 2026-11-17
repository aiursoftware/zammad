# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the user's Department is a text field with suggestions, no HR app sync
# (see Wcl::Setup.department_text_field).
class WclDepartmentTextField < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run Wcl::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.department_text_field
  end
end
