# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: field settings that Admin > Objects has no input for, so saving a field there
# would drop them. They are carried over from the field's previous settings:
#
# - unknown: the Department dropdown also takes a typed name (User::RemembersDepartment);
# - flatten_single_branch: the ticket Category lists the group's categories directly;
# - hr_departments: the HR app's department ids (User::HrDepartments).
#
# The ticket Category also keeps an entry for every active group (Group::RenamesTicketCategories):
# an entry removed by hand comes back empty, so the group's link isn't lost to a retyped name.
# To stop a group offering categories, remove the categories under it.
module ObjectManager::Attribute::KeepsWclOptions
  extend ActiveSupport::Concern

  KEPT = %w[unknown flatten_single_branch hr_departments].freeze

  included do
    before_save :keep_wcl_options, if: -> { persisted? && will_save_change_to_data_option? }
    before_save :keep_group_category_entries, if: -> { name == 'category' && will_save_change_to_data_option? }
  end

  private

  def keep_wcl_options
    before = (data_option_was || {}).to_h.stringify_keys
    after  = (data_option || {}).to_h.stringify_keys
    missing = KEPT.select { |key| before.key?(key) && !after.key?(key) }
    return if missing.empty?

    self.data_option = data_option.merge(before.slice(*missing))
  end

  def keep_group_category_entries
    return if object_lookup_id != ObjectLookup.by_name('Ticket')

    options = Array(data_option['options']).map { |option| option.to_h.deep_stringify_keys }
    known   = options.map { |option| option['name'].to_s.strip.downcase }
    missing = Group.where(active: true).filter_map { |group| group.name_last.to_s.strip.presence }.uniq
      .reject { |group_name| known.include?(group_name.downcase) }
    return if missing.empty?

    self.data_option = data_option.merge('options' => options + missing.map { |group_name| { 'name' => group_name, 'value' => group_name, 'children' => [] } })
  end
end
