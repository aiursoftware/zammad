# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: while admins keep the Department list themselves (no HR app yet, see
# HrPortal::Setup.without_hr_app), a department typed on a user that isn't in the dropdown yet is
# added to it, so the next user can pick it.
module User::RemembersDepartment
  extend ActiveSupport::Concern

  included do
    after_save :remember_department, if: -> { has_attribute?(:department) && saved_change_to_department? }
  end

  private

  def remember_department
    name = department.to_s.strip
    return if name.blank?

    attribute = ObjectManager::Attribute.get(object: 'User', name: 'department')
    return if !attribute || !attribute.data_option['unknown']

    options = Array(attribute.data_option['options'])
    return if options.any? { |option| option['value'].to_s.casecmp?(name) }

    options = (options + [{ 'value' => name, 'name' => name }]).sort_by { |option| option['name'].to_s.downcase }
    attribute.data_option = attribute.data_option.merge('options' => options)
    attribute.save!
  end
end
