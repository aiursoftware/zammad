# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the ticket Location becomes free text (was a dropdown), see Wcl::Setup.
class WclLocationFreeText < ActiveRecord::Migration[7.2]
  def up
    # return if it's a new setup (the seeds run Wcl::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.location_free_text
  end
end
