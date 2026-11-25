# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: system notifications (agent notifications, invitations, password resets)
#   go out through the Microsoft 365 Graph email account instead of the SMTP "Notification"
#   account, so no SMTP is needed (Admin > Channels > Email > Settings > "Send notifications
#   through Microsoft 365 Graph").
#
# Graph sends as its own mailbox, so the sender keeps the "Notification Sender" display name with
#   the Graph mailbox's address. With several Graph accounts, the one whose mailbox is the
#   Notification Sender's address wins, else the oldest. Without an active Graph account the
#   "Notification" account is used as before.
module Wcl::GraphNotifications
  SETTING = 'wcl_notifications_via_graph'.freeze
  AREA    = 'MicrosoftGraph::Account'.freeze

  def self.channel
    return if Setting.get(SETTING) != true

    channels = Channel.where(area: AREA, active: true).reorder(:id).to_a
    return if channels.empty?

    sender_address = parse(Setting.get('notification_sender'))&.address.to_s
    channels.find { |channel| mailbox(channel).casecmp?(sender_address) } || channels.first
  end

  def self.sender(channel)
    address = Mail::Address.new(mailbox(channel))
    address.display_name = parse(Setting.get('notification_sender'))&.display_name.presence || Setting.get('product_name')
    address.to_s
  end

  def self.mailbox(channel)
    options = channel.options.dig(:outbound, :options) || {}
    (options[:shared_mailbox].presence || options[:user]).to_s
  end

  def self.parse(value)
    Mail::Address.new(value.to_s)
  rescue Mail::Field::ParseError
    nil
  end
  private_class_method :parse
end
