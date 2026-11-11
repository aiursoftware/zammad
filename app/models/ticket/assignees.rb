# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the "Assigned to" field (attribute `assignees`, added by the TicketAssignees
# migration) assigns a ticket to several agents in one step.
#
# - The first agent picked is the owner (the single Owner field is hidden on the ticket screens).
# - Every agent picked is subscribed to the ticket (Zammad's mentions), so all of them are
#   notified and find it under "My Subscribed Tickets"; dropping one unsubscribes them.
# - Changing the owner on its own swaps them into the list in place of the old owner.
module Ticket::Assignees
  extend ActiveSupport::Concern

  included do
    before_save  :assignees_sync_owner
    after_save   :assignees_remember_change
    after_commit :assignees_sync_subscriptions, on: %i[create update]
  end

  def assignee_ids
    return [] if !has_attribute?(:assignees)

    Array(self[:assignees]).map(&:to_i).select { |id| id > 1 }.uniq
  end

  private

  def assignees_enabled?
    has_attribute?(:assignees) && !Setting.get('import_mode')
  end

  def assignees_sync_owner
    return if !assignees_enabled?

    ids = assignee_ids
    if will_save_change_to_attribute?(:assignees)
      self.owner_id = ids.first if ids.any?
    elsif will_save_change_to_owner_id? && ids.any? && owner_id.to_i > 1 && ids.exclude?(owner_id)
      ids.delete(owner_id_in_database)
      self.assignees = [owner_id, *ids].map(&:to_s)
    end
  end

  # A request may save the ticket more than once in a transaction, and after_commit only sees the
  # last save's changes, so the list from before the first change is kept until the commit.
  def assignees_remember_change
    return if !assignees_enabled?
    return if !saved_change_to_attribute?(:assignees)

    return if !@assignees_before_commit.nil?

    @assignees_before_commit = Array(attribute_before_last_save(:assignees)).map(&:to_i)
  end

  def assignees_sync_subscriptions
    return if !assignees_enabled?

    before = @assignees_before_commit
    @assignees_before_commit = nil
    return if before.nil?

    after = assignee_ids

    # After the commit the request's user is no longer set; the subscriptions are recorded as
    # made by whoever last changed the ticket.
    original_user_id = UserInfo.current_user_id
    UserInfo.current_user_id = original_user_id || updated_by_id || 1
    (after - before).each { |id| assignees_subscription(:subscribe!, id) }
    (before - after).each { |id| assignees_subscription(:unsubscribe!, id) }
  ensure
    UserInfo.current_user_id = original_user_id if !before.nil?
  end

  def assignees_subscription(action, user_id)
    user = User.find_by(id: user_id)
    return if !user

    Mention.public_send(action, self, user)
  rescue => e
    # e.g. an agent without access to the ticket's group cannot be subscribed to it
    Rails.logger.warn "Ticket #{id}: could not #{action.to_s.delete('!')} user #{user_id}: #{e.message}"
  end
end
