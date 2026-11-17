# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: Admin > Organizations > "Assign users by domain" (see Wcl::DomainAssignment).
class WclOrganizationsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  # POST /api/v1/wcl/organizations/assign_by_domain(?organization_id=1)
  def assign_by_domain
    organization = Organization.find(params[:organization_id]) if params[:organization_id].present?
    assigned     = Wcl::DomainAssignment.apply(organization)

    render json: { assigned: assigned, total: assigned.values.sum }
  end
end
