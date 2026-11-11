# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::HrPortalDepartmentsControllerPolicy < Controllers::ApplicationControllerPolicy
  # admin.user: it changes users' department; the HR app's token has it already.
  default_permit!(['admin.user', 'admin.object'])
end
