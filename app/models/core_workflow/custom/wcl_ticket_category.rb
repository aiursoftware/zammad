# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the ticket's Category offers only the categories of the chosen group.
#
# The Category field (a tree, see HrPortal::Setup.ticket_category) has a group's name on its first
# level and that group's categories below it. For the selected group the field lists those
# categories and must be filled in; a group without categories hides it.
class CoreWorkflow::Custom::WclTicketCategory < CoreWorkflow::Custom::Backend
  FIELD = 'category'.freeze

  def saved_attribute_match?
    object?(Ticket)
  end

  def selected_attribute_match?
    object?(Ticket)
  end

  def perform
    values = category_values
    if values.blank?
      result('remove', FIELD)
      result('set_optional', FIELD)
      return
    end

    result('show', FIELD)
    result('set_fixed_to', FIELD, values)
    # Only on the new-ticket form: tickets from before the field existed can still be edited.
    result(screen?('create_middle') ? 'set_mandatory' : 'set_optional', FIELD)
  end

  private

  # "Maintenance::Office maintenance", ... for the selected group (matched by its full or last
  # name, ignoring case), including deeper levels.
  def category_values
    group = selected&.group
    return [] if !group

    names  = [group.name, group.name_last].compact.map(&:downcase)
    branch = options.find { |option| names.include?(option['name'].to_s.strip.downcase) }
    return [] if !branch

    leaf_values(branch['children'])
  end

  def leaf_values(children)
    Array(children).flat_map do |child|
      child['children'].present? ? leaf_values(child['children']) : [child['value'].to_s]
    end
  end

  def options
    attribute = ObjectManager::Attribute.get(object: 'Ticket', name: FIELD)
    Array(attribute&.data_option&.dig('options'))
  end
end
