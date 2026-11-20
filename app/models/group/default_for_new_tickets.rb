# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: "Default for new tickets" on a group (attribute `wcl_default_group`, added by
#   Wcl::Setup.default_group). The new-ticket form preselects that group for everyone allowed to
#   create tickets in it (see CoreWorkflow::Custom::WclDefaultGroup). Only one group can be the
#   default: switching it on for a group switches it off for the others.
module Group::DefaultForNewTickets
  extend ActiveSupport::Concern

  ATTRIBUTE = 'wcl_default_group'.freeze

  included do
    after_save :default_for_new_tickets_only_one
  end

  class_methods do
    # The active default group, or nil.
    def default_for_new_tickets
      return if column_names.exclude?(ATTRIBUTE)

      find_by(ATTRIBUTE => true, active: true)
    end
  end

  private

  def default_for_new_tickets_only_one
    return if !has_attribute?(ATTRIBUTE)
    return if !saved_change_to_attribute?(ATTRIBUTE) || !self[ATTRIBUTE]

    # update_all: no callbacks, so the other groups' "Customers can create tickets here" sync is left alone
    Group.where.not(id: id).where(ATTRIBUTE => true).update_all(ATTRIBUTE => false, updated_at: Time.zone.now) # rubocop:disable Rails/SkipsModelValidations
  end
end
