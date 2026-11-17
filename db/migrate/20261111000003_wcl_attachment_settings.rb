# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: what employees may attach from the HR app, managed in Zammad
# (Admin → Ticket → Settings → Base) and read through GET /api/v1/wcl/attachment_rules (see WclReportsController).
class WclAttachmentSettings < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::AttachmentRules.create_settings
  end
end
