# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: "Default for new tickets" on groups (see Group::DefaultForNewTickets).
class WclDefaultGroup < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.default_group
  end
end
