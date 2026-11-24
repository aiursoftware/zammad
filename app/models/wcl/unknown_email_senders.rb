# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: incoming email never creates user accounts (Admin > Channels > Email >
#   Settings > "Accept email only from existing users"). While on,
#
# - mail from a sender without an account is dropped (Channel::Filter::WclBlockUnknownSenders),
# - addresses in To/Cc without an account are not turned into users (Channel::Filter::BaseIdentifyUser).
#
# Separately, mail from the addresses under "Blocked email addresses" is always dropped; deleting a
#   user can add their address there (Delete user > "Block their email address?").
module Wcl::UnknownEmailSenders
  SETTING          = 'wcl_email_only_existing_users'.freeze
  BLOCKED_SETTING  = 'wcl_blocked_email_addresses'.freeze
  FILTER           = '0014_postmaster_filter_wcl_block_unknown_senders'.freeze

  def self.enabled?
    Setting.get(SETTING) == true
  end

  # The "Blocked email addresses" list, one address per line.
  def self.blocked
    Setting.get(BLOCKED_SETTING).to_s.split(%r{[\s,;]+}).map { |address| address.strip.downcase }.compact_blank.uniq
  end

  def self.blocked?(email)
    return false if email.blank?

    blocked.include?(email.to_s.strip.downcase)
  end

  def self.block!(email)
    email = email.to_s.strip.downcase
    return if email.blank? || blocked?(email)

    Setting.set(BLOCKED_SETTING, (blocked + [email]).join("\n"))
  end

  def self.known?(email)
    return false if email.blank?

    User.exists?(email: email.to_s.strip.downcase)
  end
end
