# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: rejected requests stay in the employee's My Tickets / My Organization Tickets.
class WclRejectedInCustomerOverviews < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.rejected_in_customer_overviews
  end
end
