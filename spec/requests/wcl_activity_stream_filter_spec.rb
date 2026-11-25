# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'WCL Activity Stream filters', type: :request do
  let(:group)              { create(:group) }
  let(:other_group)        { create(:group) }
  # New groups give the agent role access (Group::CustomerSelectable); this one must stay closed.
  let(:inaccessible_group) { create(:group).tap { |group| RoleGroup.where(group_id: group.id).delete_all } }
  let(:agent)              { create(:agent, groups: [group, other_group]) }
  let(:teammate)           { create(:agent, groups: [group]) }

  let(:own_ticket)      { create(:ticket, group: group, created_by_id: agent.id, updated_by_id: agent.id) }
  let(:teammate_ticket) { create(:ticket, group: other_group, created_by_id: teammate.id, updated_by_id: teammate.id) }
  let(:hidden_ticket)   { create(:ticket, group: inaccessible_group) }

  def entry(object, o_id)
    ActivityStream.find_by(activity_stream_object_id: ObjectLookup.by_name(object), o_id: o_id)
  end

  def ids_for(filter)
    get '/api/v1/activity_stream', params: { limit: 100, filter: filter }, as: :json
    expect(response).to have_http_status(:ok)
    json_response.pluck('id')
  end

  before do
    own_ticket
    teammate_ticket
    hidden_ticket
    create(:organization, created_by_id: agent.id, updated_by_id: agent.id)
  end

  describe 'GET /api/v1/activity_stream with filter', authenticated_as: :agent do
    it 'narrows by object', :aggregate_failures do
      expect(ids_for(object: 'ticket')).to include(entry('Ticket', own_ticket.id).id, entry('Ticket', teammate_ticket.id).id)
      expect(ActivityStream.where(id: ids_for(object: 'ticket')).map { |a| a.object.name }.uniq - %w[Ticket Ticket::Article]).to be_empty
    end

    it 'narrows by actor', :aggregate_failures do
      expect(ids_for(actor: 'me')).to include(entry('Ticket', own_ticket.id).id)
      expect(ids_for(actor: 'me')).not_to include(entry('Ticket', teammate_ticket.id).id)
      expect(ids_for(actor: 'others')).to include(entry('Ticket', teammate_ticket.id).id)
      expect(ids_for(actor: 'others')).not_to include(entry('Ticket', own_ticket.id).id)
    end

    it 'narrows by group' do
      expect(ids_for(group: other_group.id)).to contain_exactly(entry('Ticket', teammate_ticket.id).id)
    end

    it 'narrows by action and time', :aggregate_failures do
      expect(ActivityStream.where(id: ids_for(action: 'create')).map { |a| a.type.name }.uniq).to eq(['create'])
      travel_to 2.days.from_now do
        expect(ids_for(since: 'today')).to be_empty
        expect(ids_for(since: '7d')).to include(entry('Ticket', own_ticket.id).id)
      end
    end

    it 'never widens access: a filter on an inaccessible group returns nothing', :aggregate_failures do
      expect(ids_for(group: inaccessible_group.id)).to be_empty
      expect(ids_for(object: 'ticket')).not_to include(entry('Ticket', hidden_ticket.id)&.id)
    end

    it 'ignores unknown values instead of failing' do
      expect(ids_for(object: 'nope', actor: "1'; drop", since: 'forever')).to include(entry('Ticket', own_ticket.id).id)
    end
  end
end
