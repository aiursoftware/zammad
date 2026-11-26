# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the device list of Admin > System > Phone View.
class WclPhoneViewDevices < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.phone_view_devices
  end
end
