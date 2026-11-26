# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: messages are public only (see Ticket::Article::WclPublicOnly); new notes start
#   public too, and the reply box has no message-type picker.
class WclPublicMessagesOnly < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Wcl::Setup.public_messages_only
    Setting.set(Ticket::Article::WclPublicOnly::SETTING, true)
    Setting.set('ui_ticket_zoom_article_note_new_internal', false)
    Setting.set('wcl_hide_article_type_picker', true)
  end
end
