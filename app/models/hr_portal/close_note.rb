# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: a person closing (or rejecting) a ticket writes a note saying why, in the
# same update. Rejecting needs a note the customer can see (not internal), so they learn why.
# Checked on ticket updates through the web app and the REST API; system changes (triggers,
# scheduler, macros) are left alone.
module HrPortal::CloseNote
  MESSAGE        = __('Please write a note before closing the ticket: what was done, or why it is closed.')
  MESSAGE_REJECT = __('Rejecting needs a public note that the requester can see: explain why it is rejected (switch the note from internal to public).')

  REJECTED = 'rejected'.freeze

  # The message to show, or nil when the update is fine.
  def self.problem(ticket, state_id, article)
    return if state_id.blank? || state_id.to_s == ticket.state_id.to_s

    state = Ticket::State.find_by(id: state_id)
    return if state&.state_type&.name != 'closed'

    body = article.respond_to?(:[]) ? article[:body] : nil
    return (state.name == REJECTED ? MESSAGE_REJECT : MESSAGE) if blank_text?(body)
    return MESSAGE_REJECT if state.name == REJECTED && internal?(article)

    nil
  end

  def self.missing?(ticket, state_id, article)
    problem(ticket, state_id, article).present?
  end

  def self.blank_text?(body)
    Nokogiri::HTML.fragment(body.to_s).text.gsub(%r{[[:space:]]+}, '').empty?
  end

  def self.internal?(article)
    ActiveModel::Type::Boolean.new.cast(article[:internal]) == true
  end
end
