# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: incoming email no longer creates user accounts (see Wcl::UnknownEmailSenders).
class WclEmailOnlyExistingUsers < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.email_only_existing_users
    Setting.set(Wcl::UnknownEmailSenders::SETTING, true)
  end
end
