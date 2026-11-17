# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: closing a ticket needs a note in the same update, rejecting a public one.
# Checked on REST (single and bulk) and GraphQL updates; a macro that sets the state itself is exempt.
module Wcl::CloseNote
  MESSAGE        = __('Please write a note before closing the ticket: what was done, or why it is closed.')
  MESSAGE_REJECT = __('Rejecting needs a public note that the requester can see: explain why it is rejected (switch the note from internal to public).')

  REJECTED = 'rejected'.freeze

  # The message to show, or nil when the update is fine.
  def self.problem(ticket, state_id, article, macro: nil)
    return if state_id.blank? || state_id.to_s == ticket.state_id.to_s
    return if macro_sets_state?(macro, state_id)

    state = Ticket::State.find_by(id: state_id)
    return if state&.state_type&.name != 'closed'

    body = article.respond_to?(:[]) ? article[:body] : nil
    return (state.name == REJECTED ? MESSAGE_REJECT : MESSAGE) if blank_text?(body)
    return MESSAGE_REJECT if state.name == REJECTED && internal?(article)

    nil
  end

  # REST clients send the macro id; only an existing, active macro the agent may run counts.
  def self.macro_for(user, macro_id)
    return if macro_id.blank? || !user&.permissions?('ticket.agent')

    Macro.find_by(id: macro_id, active: true)
  end

  def self.macro_sets_state?(macro, state_id)
    return false if !macro

    macro.perform&.dig('ticket.state_id', 'value').to_s == state_id.to_s
  end

  def self.blank_text?(body)
    Nokogiri::HTML.fragment(body.to_s).text.gsub(%r{[[:space:]]+}, '').empty?
  end

  def self.internal?(article)
    ActiveModel::Type::Boolean.new.cast(article[:internal]) == true
  end
end
