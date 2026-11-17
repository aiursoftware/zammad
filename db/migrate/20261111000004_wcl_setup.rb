# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the rest of the HR app integration (Rejected state, urgent priority,
# settings, the open-requests overview); see HrPortal::Setup.
class HrPortalSetup < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run HrPortal::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    HrPortal::Setup.run
  end
end
