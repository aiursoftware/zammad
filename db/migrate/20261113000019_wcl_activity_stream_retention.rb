# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: Admin > Dashboard > "Keep activities for" (see ActivityStream.cleanup).
class WclActivityStreamRetention < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.activity_stream_retention
  end
end
