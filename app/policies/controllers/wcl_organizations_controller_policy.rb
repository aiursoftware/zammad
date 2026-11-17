# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::WclOrganizationsControllerPolicy < Controllers::ApplicationControllerPolicy
  permit! :assign_by_domain, to: 'admin.organization'
end
