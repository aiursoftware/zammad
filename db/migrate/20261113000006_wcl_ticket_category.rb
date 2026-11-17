# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: ticket Category listed by group, replacing "Maintenance type" (see HrPortal::Setup).
class HrPortalTicketCategory < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run HrPortal::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    HrPortal::Setup.ticket_category
    HrPortal::Setup.retire_maintenance_type
  end
end
