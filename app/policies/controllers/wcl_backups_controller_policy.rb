# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::WclBackupsControllerPolicy < Controllers::ApplicationControllerPolicy
  default_permit!('admin.maintenance')
end
