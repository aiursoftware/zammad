# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the user's Department is a dropdown of the HR app's departments, managed in
# the HR app only. The HR app sends its active departments (PUT /api/v1/hr_portal/departments,
# see HrPortalDepartmentsController) and this keeps the field in step:
#
# - the dropdown lists them, by name (the name is what is stored on the user);
# - a renamed department (same HR id, new name) is renamed on its users and in the HR-portal
#   department overviews, which the HR app finds by a link made from the name.
module User::HrDepartments
  ATTRIBUTE = { object: 'User', name: 'department' }.freeze

  # departments: [{ id: 3, name: 'Warehouse' }, ...], the HR app's active ones.
  # Returns the renames done, { 'Old name' => 'New name' }.
  def self.sync(departments)
    attribute = ObjectManager::Attribute.get(**ATTRIBUTE)
    raise Exceptions::UnprocessableContent, __('The user attribute "department" is missing.') if !attribute

    current = by_id(departments)
    renames = renames(attribute, current)
    renames.each { |from, to| rename(from, to) }

    update_options(attribute, current)
    renames
  end

  # { "3" => "Warehouse" }, blanks and repeated ids left out.
  def self.by_id(departments)
    departments
      .map { |dep| [dep[:id].to_s, dep[:name].to_s.strip] }
      .reject { |id, name| id.blank? || name.blank? }
      .uniq(&:first)
      .to_h
  end

  # A department the HR app sent before under another name: { 'Old name' => 'New name' }.
  def self.renames(attribute, current)
    known = (attribute.data_option[:hr_departments] || {}).to_h.transform_keys(&:to_s)
    current.filter_map { |id, name| [known[id], name] if known[id].present? && known[id] != name }.to_h
  end

  def self.update_options(attribute, current)
    options     = current.values.uniq.sort_by(&:downcase).map { |name| { 'value' => name, 'name' => name } }
    data_option = attribute.data_option.merge(options: options, hr_departments: current)
    return if data_option == attribute.data_option

    attribute.data_option = data_option
    attribute.save!
  end

  def self.rename(from, to)
    User.where(department: from).find_each { |user| user.update!(department: to) }

    Overview.find_each do |overview|
      condition = overview.condition.deep_dup
      rule      = condition['customer.department']
      next if rule.blank? || Array(rule['value']).exclude?(from)

      rule['value'] = Array(rule['value']).map { |value| value == from ? to : value }
      changes = { condition: condition }
      changes[:link] = "hr_portal_dept_#{slug(to)}" if overview.link == "hr_portal_dept_#{slug(from)}"
      changes[:name] = overview.name.sub(from, to) if overview.name.include?(from)
      overview.update!(changes)
    end
  end

  # Same as the HR app's SupportTicketService.Slug: "Kế toán" → "ke_toan".
  def self.slug(value)
    plain = value.tr('đĐ', 'dD').unicode_normalize(:nfd).gsub(%r{\p{Mn}}, '')
    slug  = plain.gsub(%r{[^A-Za-z0-9]}, '_').downcase.split('_').compact_blank.join('_')
    slug.presence || 'department'
  end
end
