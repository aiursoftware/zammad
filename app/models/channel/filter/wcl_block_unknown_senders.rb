# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: drops incoming mail from blocked addresses, and (while switched on) mail whose
#   sender has no user account, so email can't create accounts for strangers (see Wcl::UnknownEmailSenders). Runs after the Reply-To
#   filter (the sender may come from Reply-To) and before the filters that look up or create users.
module Channel::Filter::WclBlockUnknownSenders
  def self.run(_channel, mail, _transaction_params)
    return if ['true', true].include?(mail[:'x-zammad-ignore'])

    email = mail[:'x-zammad-customer-email'].presence || mail[:from_email]
    return ignore(mail, email, 'address is blocked') if Wcl::UnknownEmailSenders.blocked?(mail[:from_email]) || Wcl::UnknownEmailSenders.blocked?(email)
    return if !Wcl::UnknownEmailSenders.enabled?

    # set by a trusted source (Channel::Filter::Trusted removes it from untrusted mail)
    return if mail[:'x-zammad-session-user-id'].present?
    return if Wcl::UnknownEmailSenders.known?(email)

    ignore(mail, email, 'sender has no user account')
  end

  def self.ignore(mail, email, reason)
    Rails.logger.info "WCL: ignored email with msgid '#{mail[:message_id]}' from '#{email}': #{reason}"
    mail[:'x-zammad-ignore'] = true
  end
end
