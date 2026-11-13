# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: a person closing (or rejecting) a ticket writes a note saying why, in the
# same update. Checked on ticket updates through the web app and the REST API; system changes
# (triggers, scheduler, macros) are left alone.
module HrPortal::CloseNote
  MESSAGE = __('Please write a note before closing the ticket: what was done, or why it is closed.')

  def self.missing?(ticket, state_id, article)
    return false if state_id.blank? || state_id.to_s == ticket.state_id.to_s

    state = Ticket::State.find_by(id: state_id)
    return false if state&.state_type&.name != 'closed'

    body = article.respond_to?(:[]) ? article[:body] : nil
    text = Nokogiri::HTML.fragment(body.to_s).text
    text.gsub(%r{[[:space:]]+}, '').empty?
  end
end
