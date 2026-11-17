# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: Wcl::CloseNote for the new UI. Raises a plain error (not a BaseError) so
# clients cannot skip it via skipValidators.
class Service::Ticket::Update::Validator
  class WclCloseNote < Base
    def valid!
      state = ticket_data && ticket_data[:state]
      return if !state

      problem = Wcl::CloseNote.problem(ticket, state.id, article_data || {}, macro:)
      raise Exceptions::UnprocessableContent, problem if problem
    end
  end
end
