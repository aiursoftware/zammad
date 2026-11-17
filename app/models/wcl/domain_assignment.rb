# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: applies an organization's "Domain based assignment" to users who already
# exist (Zammad itself only does it when a user is created). Users with an organization are left
# alone.
module Wcl::DomainAssignment
  # { "WorldCraft Logistics" => 12, ... } for the given organization, or every one with the switch on.
  def self.apply(organization = nil)
    organizations = organization ? [organization] : Organization.where(domain_assignment: true, active: true).where.not(domain: [nil, ''])

    organizations.each_with_object({}) do |org, result|
      next if !org.domain_assignment || org.domain.blank?

      result[org.name] = users_for(org.domain).count { |user| user.update(organization_id: org.id) }
    end
  end

  def self.users_for(domain)
    pattern = "%@#{User.sanitize_sql_like(domain.to_s.strip.downcase)}"
    User.where(organization_id: nil).where.not(id: 1).where('LOWER(email) LIKE ?', pattern).to_a
  end
end
