# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization, see HrPortalDepartmentsController.
Zammad::Application.routes.draw do
  scope Rails.configuration.api_path do
    put 'hr_portal/departments',     to: 'hr_portal_departments#update'
    get 'hr_portal/attachment_rules', to: 'hr_portal_departments#attachment_rules'
  end
end
