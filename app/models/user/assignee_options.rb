# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: keeps the agents listed in the ticket's "Assigned to" field (attribute
# `assignees`, see Ticket::Assignees) up to date as agents are added, renamed or removed.
module User::AssigneeOptions
  extend ActiveSupport::Concern

  included do
    after_commit :assignee_options_refresh
  end

  # Every active agent, by name, in the tree select's shape: [{ "value" => "12", "name" => "Lan Nguyen" }].
  def self.options
    User.with_permissions('ticket.agent')
      .where(active: true)
      .where.not(id: 1)
      .sort_by { |user| user.fullname.downcase }
      .map { |user| { 'value' => user.id.to_s, 'name' => user.fullname } }
  end

  def self.refresh
    attribute = ObjectManager::Attribute.get(object: 'Ticket', name: 'assignees')
    return if !attribute

    options = self.options
    return if attribute.data_option[:options] == options

    attribute.data_option = attribute.data_option.merge(options: options)
    attribute.save!
  end

  private

  def assignee_options_refresh
    return if Setting.get('import_mode')
    return if Setting.get('system_init_done').blank?

    # Customers come and go far more often than agents; only an agent, or someone who was one, matters.
    attribute = ObjectManager::Attribute.get(object: 'Ticket', name: 'assignees')
    return if !attribute

    listed = Array(attribute.data_option[:options]).any? { |option| option['value'] == id.to_s }
    return if !permissions?('ticket.agent') && !listed

    User::AssigneeOptions.refresh
  end
end
