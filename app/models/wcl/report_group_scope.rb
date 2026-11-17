# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: limits a Reporting profile's ticket condition to the groups a user may read,
# so a manager of one team doesn't see another team's numbers or tickets.
module Wcl::ReportGroupScope
  FIELD    = 'ticket.group_id'.freeze
  NO_GROUP = '0'.freeze

  def self.restrict(condition, user)
    readable  = user.group_ids_access('read').map(&:to_s)
    condition = (condition || {}).deep_dup.with_indifferent_access

    if condition.key?(:conditions)
      return { operator: 'AND', conditions: [condition, { name: FIELD, operator: 'is', value: readable.presence || [NO_GROUP] }] }.with_indifferent_access
    end

    condition[FIELD] = { operator: 'is', value: allowed(condition[FIELD], readable).presence || [NO_GROUP] }
    condition
  end

  def self.allowed(existing, readable)
    return readable if existing.blank?

    values = Array(existing[:value]).map(&:to_s)
    existing[:operator] == 'is not' ? readable - values : readable & values
  end
end
