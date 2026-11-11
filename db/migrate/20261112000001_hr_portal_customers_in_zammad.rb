# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: employees create tickets in Zammad itself for now; the group switch gets its
# new name and customers may pick the priority (see HrPortal::Setup).
class HrPortalCustomersInZammad < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run HrPortal::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    HrPortal::Setup.group_hr_portal_label
    HrPortal::Setup.customer_priority
  end
end
