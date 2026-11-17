# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: ticket Category listed by group, replacing "Maintenance type" (see Wcl::Setup).
class WclTicketCategory < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run Wcl::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.ticket_category
    Wcl::Setup.retire_maintenance_type
  end
end
