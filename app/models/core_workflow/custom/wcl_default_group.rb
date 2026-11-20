# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the new-ticket form starts on the group marked "Default for new tickets"
#   (see Group::DefaultForNewTickets).
#
# Only while the group field is still empty, so a group picked by hand (or by a template) is
# never overwritten. Zammad's "select" ignores a group the user may not create tickets in, so
# employees only get the default when it is one of their selectable groups.
class CoreWorkflow::Custom::WclDefaultGroup < CoreWorkflow::Custom::Backend
  FIELD = 'group_id'.freeze

  def selected_attribute_match?
    object?(Ticket)
  end

  def perform
    return if !screen?('create_middle')
    return if params&.dig(FIELD).present?

    group = Group.default_for_new_tickets
    return if !group

    result('select', FIELD, group.id.to_s)
  end
end
