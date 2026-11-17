# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: "Manager" role with team overviews (see HrPortal::Setup.manager_role).
class HrPortalManagerRole < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run HrPortal::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    HrPortal::Setup.manager_role
  end
end
