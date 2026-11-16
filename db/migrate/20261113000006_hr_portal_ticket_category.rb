# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: "Maintenance" group with a required "Maintenance type" (see HrPortal::Setup).
class HrPortalMaintenanceType < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run HrPortal::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    HrPortal::Setup.maintenance_type
  end
end
