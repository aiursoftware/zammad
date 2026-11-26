# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: Admin > System > Server Files (see Wcl::ServerFiles). Read-only.
class WclServerFilesController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  # GET /api/v1/wcl/server_files?root=logs&path=sub/folder
  def index
    render json: { root: params[:root], path: params[:path].to_s, entries: Wcl::ServerFiles.list(params[:root], params[:path]) }
  rescue Wcl::ServerFiles::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  # GET /api/v1/wcl/server_files/view?root=logs&path=rails.log
  def view
    render json: Wcl::ServerFiles.view(params[:root], params[:path])
  rescue Wcl::ServerFiles::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  # GET /api/v1/wcl/server_files/download?root=logs&path=rails.log
  def download
    file = Wcl::ServerFiles.file(params[:root], params[:path])
    send_file file, filename: file.basename.to_s, type: 'application/octet-stream', disposition: 'attachment'
  rescue Wcl::ServerFiles::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
