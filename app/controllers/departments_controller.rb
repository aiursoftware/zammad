# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: Admin > Manage > Departments (see Department).
class DepartmentsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  def index
    model_index_render(Department, params)
  end

  def show
    model_show_render(Department, params)
  end

  def create
    model_create_render(Department, params)
  end

  def update
    model_update_render(Department, params)
  end

  def destroy
    model_destroy_render(Department, params)
  end

  # GET /api/v1/departments/:id/members
  def members
    render json: department.members.map { |user| member_json(user) }
  end

  # GET /api/v1/departments/:id/candidates?query=lan
  def candidates
    render json: department.candidates(params[:query]).map { |user| member_json(user) }
  end

  # POST /api/v1/departments/:id/members { user_id: 12 }
  def add_member
    department.add_member(User.find(params[:user_id]))
    render json: { ok: true }
  end

  # DELETE /api/v1/departments/:id/members/:user_id
  def remove_member
    department.remove_member(User.find(params[:user_id]))
    render json: { ok: true }
  end

  private

  def department
    @department ||= Department.find(params[:id])
  end

  def member_json(user)
    { id: user.id, name: user.fullname, email: user.email, department: user.department.presence }
  end
end
