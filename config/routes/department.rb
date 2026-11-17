# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

Zammad::Application.routes.draw do
  api_path = Rails.configuration.api_path

  # departments (WCL)
  match api_path + '/departments',     to: 'departments#index',   via: :get
  match api_path + '/departments/:id', to: 'departments#show',    via: :get
  match api_path + '/departments',     to: 'departments#create',  via: :post
  match api_path + '/departments/:id', to: 'departments#update',  via: :put
  match api_path + '/departments/:id', to: 'departments#destroy', via: :delete
end
