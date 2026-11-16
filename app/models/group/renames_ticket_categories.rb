# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the ticket Category lists a group's categories under a top-level entry named
# like the group (see CoreWorkflow::Custom::WclTicketCategory). That entry follows the group:
#
# - a new group gets an empty entry, ready for its categories (Admin > Objects > Ticket > Category);
# - a renamed group renames its entry and the Category of its existing tickets
#   ("Old name::Office" -> "New name::Office"), so the categories keep showing.
module Group::RenamesTicketCategories
  extend ActiveSupport::Concern

  # Adds an empty entry for each of the groups that has none yet (the group's last name part, as a
  # sub-group's full name contains "::"). Returns the names added.
  def self.add_category_entries(groups)
    attribute = ObjectManager::Attribute.get(object: 'Ticket', name: 'category')
    return [] if !attribute

    options = Array(attribute.data_option['options']).map { |option| option.to_h.deep_stringify_keys }
    known   = options.map { |option| option['name'].to_s.strip.downcase }
    added   = groups.map { |group| group.name_last.to_s.strip }.compact_blank.uniq.reject { |name| known.include?(name.downcase) }
    return [] if added.empty?

    options += added.map { |name| { 'name' => name, 'value' => name, 'children' => [] } }
    attribute.data_option = attribute.data_option.merge('options' => options)
    attribute.save!
    added
  end

  included do
    after_create :add_ticket_category_entry, if: -> { !Setting.get('import_mode') }
    after_update :rename_ticket_category_branch, if: -> { saved_change_to_name? || saved_change_to_name_last? }
  end

  private

  def add_ticket_category_entry
    Group::RenamesTicketCategories.add_category_entries([self])
  end

  def rename_ticket_category_branch
    attribute = ObjectManager::Attribute.get(object: 'Ticket', name: 'category')
    return if !attribute

    options = Array(attribute.data_option['options']).map { |option| option.to_h.deep_stringify_keys }
    branch, from, to = category_branch_rename(options)
    return if !branch

    rename_category_values(branch, from, to)
    branch['name'] = to
    attribute.data_option = attribute.data_option.merge('options' => options)
    attribute.save!

    rename_ticket_categories(from, to)
  end

  # The entry named like the group before (full name, or last part for a sub-group), and the
  # names to change it from and to.
  def category_branch_rename(options)
    candidates = [[name_before_last_save, name], [name_last_before_last_save, name_last]]
    candidates.each do |from, to|
      next if from.blank? || to.blank? || from == to

      branch = options.find { |option| option['name'].to_s.strip.casecmp?(from.to_s.strip) }
      return [branch, branch['name'].to_s, to] if branch
    end
    nil
  end

  def rename_category_values(option, from, to)
    option['value'] = renamed_category(option['value'], from, to)
    Array(option['children']).each { |child| rename_category_values(child, from, to) }
  end

  def renamed_category(value, from, to)
    value = value.to_s
    return to if value == from
    return "#{to}#{value.delete_prefix(from)}" if value.start_with?("#{from}::")

    value
  end

  def rename_ticket_categories(from, to)
    return if Ticket.column_names.exclude?('category')

    Ticket.where(category: from).or(Ticket.where('category LIKE ?', "#{Ticket.sanitize_sql_like(from)}::%")).find_each do |ticket|
      ticket.update_columns(category: renamed_category(ticket.category, from, to)) # rubocop:disable Rails/SkipsModelValidations
      SearchIndexJob.perform_later('Ticket', ticket.id)
    end
  end
end
