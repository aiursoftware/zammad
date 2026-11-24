# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization, see WclReportsController, WclOrganizationsController and WclBackupsController.
Zammad::Application.routes.draw do
  scope Rails.configuration.api_path do
    get 'wcl/attachment_rules',    to: 'wcl_reports#attachment_rules'
    get 'wcl/reports/maintenance', to: 'wcl_reports#maintenance'
    post 'wcl/organizations/assign_by_domain', to: 'wcl_organizations#assign_by_domain'
    get 'wcl/backups',          to: 'wcl_backups#index'
    post 'wcl/backups',         to: 'wcl_backups#create'
    delete 'wcl/backups/:id',   to: 'wcl_backups#destroy'
  end
end
