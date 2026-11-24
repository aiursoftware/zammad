# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: optional "Target date" on tickets (see Wcl::Setup.ticket_target_date).
class WclTicketTargetDate < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.ticket_target_date
  end
end
