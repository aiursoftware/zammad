# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the HR app's calls into Zammad: it sends its departments here (see
# User::HrDepartments) and reads the attachment rules (see HrPortal::AttachmentRules).
class HrPortalDepartmentsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  # PUT /api/v1/hr_portal/departments
  # { "departments": [{ "id": 3, "name": "Warehouse" }, ...] }
  def update
    departments = Array(params.require(:departments)).map do |department|
      department.permit(:id, :name).to_h.symbolize_keys
    end
    renames = UserInfo.with_user_id(current_user.id) { User::HrDepartments.sync(departments) }

    render json: { departments: departments.size, renamed: renames }
  end

  # GET /api/v1/hr_portal/attachment_rules
  # What employees may attach in the HR app (see HrPortal::AttachmentRules).
  def attachment_rules
    render json: HrPortal::AttachmentRules.current
  end
end
