# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: Admin > System > Backups > "Create backup now" (see Wcl::Backup).
class WclBackupJob < ApplicationJob
  def perform
    Wcl::Backup.create!
  rescue => e
    Rails.logger.error "WCL backup failed: #{e.message}"
    raise
  end
end
