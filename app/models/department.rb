# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: a department, managed in Admin > Manage > Departments. The Department on
# users and tickets is a dropdown of the active departments, kept in step with this list.
# Renaming a department renames it on its users and tickets; an inactive one is no longer offered.
class Department < ApplicationModel
  include HasDefaultModelUserRelations
  include ChecksClientNotification

  # The dropdowns that list the departments.
  DROPDOWNS = [%w[User department], %w[Ticket department]].freeze

  validates :name, presence: true, length: { maximum: 200 }
  validates :name, uniqueness: { case_sensitive: false }
  validates :email, length: { maximum: 250 }, allow_blank: true
  validates :note, length: { maximum: 250 }, allow_blank: true

  before_validation :strip_name
  after_update :rename_on_users_and_tickets, if: :saved_change_to_name?
  after_commit { Department.refresh_dropdowns }

  # The active departments, A to Z, in the dropdown's shape: [{ "value" => "IT", "name" => "IT" }].
  def self.options
    return [] if !table_exists?

    where(active: true).pluck(:name).sort_by(&:downcase).map { |name| { 'value' => name, 'name' => name } }
  end

  def self.refresh_dropdowns
    options = self.options
    DROPDOWNS.each do |object, name|
      attribute = ObjectManager::Attribute.get(object: object, name: name)
      next if !attribute || attribute.data_type != 'tree_select'
      next if Array(attribute.data_option['options']) == options

      attribute.data_option = attribute.data_option.merge('options' => options)
      attribute.save!
    end
  end

  private

  def strip_name
    self.name = name.to_s.strip.squeeze(' ')
  end

  def rename_on_users_and_tickets
    from, to = saved_change_to_name
    User.where(department: from).update_all(department: to, updated_at: Time.zone.now) # rubocop:disable Rails/SkipsModelValidations
    return if Ticket.column_names.exclude?('department')

    Ticket.where(department: from).find_each do |ticket|
      ticket.update_columns(department: to) # rubocop:disable Rails/SkipsModelValidations
      SearchIndexJob.perform_later('Ticket', ticket.id)
    end
  end
end
