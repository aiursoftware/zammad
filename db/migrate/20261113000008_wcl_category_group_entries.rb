# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: every active group gets its (empty) entry in the ticket Category, see
# Group::RenamesTicketCategories.
class HrPortalCategoryGroupEntries < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run HrPortal::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    Group::RenamesTicketCategories.add_category_entries(Group.where(active: true))
  end
end
