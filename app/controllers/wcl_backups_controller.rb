# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: Admin > System > Backups (see Wcl::Backup).
class WclBackupsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  # GET /api/v1/wcl/backups
  def index
    render json: status_json
  end

  # POST /api/v1/wcl/backups
  def create
    Wcl::Backup.start!
    render json: status_json
  rescue Wcl::Backup::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  # DELETE /api/v1/wcl/backups/:id
  def destroy
    Wcl::Backup.destroy!(params[:id])
    render json: status_json
  rescue Wcl::Backup::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  # POST /api/v1/wcl/backups/delete  { ids: [...] }
  def destroy_many
    Wcl::Backup.destroy_many!(params[:ids])
    render json: status_json
  rescue Wcl::Backup::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  private

  def status_json
    { backups: Wcl::Backup.list, running: Wcl::Backup.running? }
  end
end
