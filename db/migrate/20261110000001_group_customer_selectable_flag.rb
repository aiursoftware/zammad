# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: a "Show in HR app" switch on every group (see Group::CustomerSelectable).
class GroupCustomerSelectableFlag < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run Wcl::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.group_customer_selectable_attribute
  end
end
