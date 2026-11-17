# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: customers don't pick the state of a new ticket (see HrPortal::Setup).
class HrPortalCustomersNoStateOnCreate < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run HrPortal::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    HrPortal::Setup.customers_no_state_on_create
  end
end
