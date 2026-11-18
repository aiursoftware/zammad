# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: filters for the dashboard Activity Stream.
#
# Applied on top of ActivityStream.list's permission scope, so a filter can only narrow
#   what a user may already see, never widen it. Unknown or empty values are ignored.
module Wcl::ActivityStreamFilter
  SYSTEM_USER_ID = 1
  MAX_LIMIT = 100

  OBJECTS = {
    'ticket'       => %w[Ticket Ticket::Article],
    'user'         => %w[User],
    'organization' => %w[Organization],
    'admin'        => %w[Group Role],
  }.freeze

  ACTIONS = {
    'create'  => 'create',
    'update'  => 'update',
    'session' => 'session started',
  }.freeze

  ACTORS = %w[me others people system].freeze

  SINCE = {
    'today' => -> { today_start },
    '7d'    => -> { 7.days.ago },
    '30d'   => -> { 30.days.ago },
  }.freeze

  # Keeps only recognised filter values; returns nil when nothing is set.
  def self.sanitize(raw)
    return if raw.blank?

    raw = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    raw = raw.stringify_keys

    filter = {
      'object' => raw['object'].to_s.presence_in(OBJECTS.keys),
      'action' => raw['action'].to_s.presence_in(ACTIONS.keys),
      'actor'  => raw['actor'].to_s.presence_in(ACTORS),
      'since'  => raw['since'].to_s.presence_in(SINCE.keys),
      'group'  => raw['group'].to_s.match?(%r{\A\d+\z}) ? raw['group'].to_i : nil,
    }.compact

    filter.presence
  end

  def self.limit(value)
    value.to_i.clamp(1, MAX_LIMIT)
  end

  def self.apply(scope, user, filter)
    return scope if filter.blank?

    if (names = OBJECTS[filter['object']])
      scope = scope.where(activity_stream_object_id: ObjectLookup.where(name: names).select(:id))
    end

    if (name = ACTIONS[filter['action']])
      scope = scope.where(activity_stream_type_id: TypeLookup.where(name: name).select(:id))
    end

    scope = case filter['actor']
            when 'me'     then scope.where(created_by_id: user.id)
            when 'others' then scope.where.not(created_by_id: [user.id, SYSTEM_USER_ID])
            when 'people' then scope.where.not(created_by_id: SYSTEM_USER_ID)
            when 'system' then scope.where(created_by_id: SYSTEM_USER_ID)
            else scope
            end

    scope = scope.where(group_id: filter['group']) if filter['group']
    scope = scope.where(created_at: SINCE[filter['since']].call..) if filter['since']

    scope
  end

  # Midnight in the company's timezone, not the server's.
  def self.today_start
    zone = Setting.get('timezone_default').presence || 'UTC'
    Time.use_zone(zone) { Time.zone.now.beginning_of_day }
  rescue ArgumentError
    Time.zone.now.beginning_of_day
  end
end
