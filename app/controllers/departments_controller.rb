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
end
