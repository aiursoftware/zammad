# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: a new ticket starts on the Send Email tab (Admin > Settings > Ticket > Default
#   type for a new ticket); the tab order itself is set in agent_ticket_create.coffee.
class WclTicketCreateEmailDefault < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    types = Array(Setting.get('ui_ticket_create_available_types'))
    Setting.set('ui_ticket_create_available_types', types + ['email-out']) if types.exclude?('email-out')
    Setting.set('ui_ticket_create_default_type', 'email-out')
  end
end
