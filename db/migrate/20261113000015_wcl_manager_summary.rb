# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: weekly summary email to managers (see Wcl::ManagerSummary).
class WclManagerSummary < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.manager_summary
  end
end
