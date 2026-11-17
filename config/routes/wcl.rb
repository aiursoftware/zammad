# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization, see WclReportsController.
Zammad::Application.routes.draw do
  scope Rails.configuration.api_path do
    get 'wcl/attachment_rules',    to: 'wcl_reports#attachment_rules'
    get 'wcl/reports/maintenance', to: 'wcl_reports#maintenance'
  end
end
