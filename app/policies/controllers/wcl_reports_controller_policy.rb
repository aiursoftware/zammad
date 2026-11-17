# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::WclReportsControllerPolicy < Controllers::ApplicationControllerPolicy
  permit! :maintenance, to: 'report'
  permit! :attachment_rules, to: ['admin.user', 'admin.object', 'ticket.agent']
end
