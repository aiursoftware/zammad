# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: notifications go out through the Microsoft 365 Graph account (see
#   Wcl::GraphNotifications); until a Graph account exists the notification account is used.
class WclNotificationsViaGraph < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.notifications_via_graph
    Setting.set(Wcl::GraphNotifications::SETTING, true)
  end
end
