# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: superseded by the group-based Category (HrPortalTicketCategory), which also
# moves any Maintenance type values over. Kept so installs that ran it stay in step.
class HrPortalMaintenanceType < ActiveRecord::Migration[7.2]
  def up; end
end
