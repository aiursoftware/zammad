# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: an employee's reply doesn't undo In Progress or On Hold. Their form can't
# offer those states, so it would send "open"; that change is ignored (closing still works).
module Ticket::KeepsWorkState
  extend ActiveSupport::Concern

  included do
    before_update :keep_work_state, if: :will_save_change_to_state_id?
  end

  private

  def keep_work_state
    return if !Wcl::Setup::WORK_STATES.key?(Ticket::State.lookup(id: state_id_in_database)&.name)
    return if Ticket::State.lookup(id: state_id)&.name != 'open'

    user = User.lookup(id: UserInfo.current_user_id)
    return if !user || user.id == 1 || user.permissions?('ticket.agent')

    self.state_id = state_id_in_database
  end
end
