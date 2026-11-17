# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: required free-text "Location" on new tickets (see Wcl::Setup).
class WclTicketLocation < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run Wcl::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.ticket_location
  end
end
