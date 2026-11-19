# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: the "Owners" field (attribute `assignees`) and the single owner stay in sync.
RSpec.describe Ticket::Assignees, db_strategy: :reset, type: :model do
  let(:group)   { create(:group) }
  let(:agent)   { create(:agent, groups: [group]) }
  let(:other)   { create(:agent, groups: [group]) }
  let(:ticket)  { create(:ticket, group: group) }

  before do
    Wcl::Setup.ticket_assignees_attribute
    ObjectManager::Attribute.migration_execute
  end

  it 'makes the first of the Owners the owner' do
    ticket.update!(assignees: [other.id.to_s, agent.id.to_s])

    expect(ticket.reload.owner_id).to eq(other.id)
  end

  it 'shows an owner set on its own in Owners when Owners is empty' do
    ticket.update!(owner_id: agent.id)

    expect(ticket.reload.assignees).to eq([agent.id.to_s])
  end

  it 'swaps a new owner into Owners in place of the old one' do
    ticket.update!(assignees: [agent.id.to_s])
    ticket.update!(owner_id: other.id)

    expect(ticket.reload.assignees).to eq([other.id.to_s])
  end

  it 'lets a trigger assign every new ticket of a group to a staff member', performs_jobs: true do
    create(:trigger,
           condition: {
             'ticket.action'   => { 'operator' => 'is', 'value' => 'create' },
             'ticket.group_id' => { 'operator' => 'is', 'value' => [group.id.to_s] },
           },
           perform:   { 'ticket.owner_id' => { 'pre_condition' => 'specific', 'value' => agent.id.to_s } })

    created = create(:ticket, group: group)
    TransactionDispatcher.commit

    expect(created.reload).to have_attributes(owner_id: agent.id, assignees: [agent.id.to_s])
  end
end
