# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: customers don't pick the state of a new ticket (see Wcl::Setup).
class WclCustomersNoStateOnCreate < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run Wcl::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.customers_no_state_on_create
  end
end
