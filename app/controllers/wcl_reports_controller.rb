# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: Reporting > Maintenance Report (see Wcl::MaintenanceReport), and the
# attachment rules an external form can read (see Wcl::AttachmentRules).
#
#   GET /api/v1/wcl/reports/maintenance?from=2026-11-01&to=2026-11-30&group_ids[]=4
#   ... &sheet=true downloads the Excel file instead of the JSON summary.
class WclReportsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  def maintenance
    report = Wcl::MaintenanceReport.new(
      user:      current_user,
      from:      date_param(:from, Time.zone.today.beginning_of_month),
      to:        date_param(:to, Time.zone.today),
      group_ids: params[:group_ids],
      timezone:  params[:timezone],
    )

    if ActiveModel::Type::Boolean.new.cast(params[:sheet])
      send_tempfile(report.file, filename: report.filename, type: Wcl::MaintenanceReport::CONTENT_TYPE)
      return
    end

    render json: report.data
  end

  # GET /api/v1/wcl/attachment_rules
  def attachment_rules
    render json: Wcl::AttachmentRules.current
  end

  private

  def date_param(name, default)
    return default if params[name].blank?

    Date.iso8601(params[name].to_s)
  rescue Date::Error
    raise Exceptions::UnprocessableContent, __('Please give the dates as YYYY-MM-DD.')
  end
end
