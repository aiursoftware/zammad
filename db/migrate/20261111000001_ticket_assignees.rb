# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: an "Owners" field for several agents at once (see Ticket::Assignees).
class TicketAssignees < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run HrPortal::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    HrPortal::Setup.ticket_assignees_attribute
    HrPortal::Setup.owners_core_workflow
  end
end
