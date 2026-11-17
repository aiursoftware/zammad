# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the ticket's Department is the requester's department at the time of the
# ticket (attribute `department`, see HrPortal::Setup.ticket_department), so reports by department
# stay right after someone changes department. Set when the ticket is created and when its
# customer changes; agents can correct it on the ticket.
module Ticket::StampsDepartment
  extend ActiveSupport::Concern

  included do
    before_create :stamp_department
    before_update :stamp_department, if: :will_save_change_to_customer_id?
  end

  private

  def stamp_department
    return if !has_attribute?(:department)
    return if new_record? && department.present?

    self.department = customer&.department.presence
  end
end
