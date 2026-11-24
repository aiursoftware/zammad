# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: admin schedulers run at the exact minute picked (see Job#in_timeplan?),
#   so the runner that starts them checks every minute instead of every five.
class WclSchedulerExactMinutes < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Scheduler.find_by(method: 'Job.run')&.update!(period: 1.minute)
  end
end
