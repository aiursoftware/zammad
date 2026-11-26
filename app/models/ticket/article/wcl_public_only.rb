# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: "Public messages only" (Admin > Settings > Ticket > Note - public messages
#   only, setting wcl_public_messages_only). Messages people write in the web app are always public:
#   a new one can't be internal and an existing one can't be switched to internal. Switching back
#   and forth used to re-send emails each time. Messages made by the system (triggers, email logs,
#   imports) are left alone.
module Ticket::Article::WclPublicOnly
  extend ActiveSupport::Concern

  SETTING = 'wcl_public_messages_only'.freeze

  included do
    before_create :wcl_public_only_on_create
    before_update :wcl_public_only_on_update, if: :will_save_change_to_internal?
  end

  def self.enabled?
    Setting.get(SETTING) == true
  end

  private

  def wcl_written_in_web_app?
    return false if !Ticket::Article::WclPublicOnly.enabled?
    return false if ApplicationHandleInfo.current != 'application_server'

    UserInfo.current_user_id.present? && UserInfo.current_user_id != 1
  end

  def wcl_public_only_on_create
    return if !internal || !wcl_written_in_web_app?

    self.internal = false
  end

  def wcl_public_only_on_update
    return if !internal || !wcl_written_in_web_app?

    self.internal = internal_in_database
  end
end
