# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: "Default for new tickets" on groups.
RSpec.describe CoreWorkflow::Custom::WclDefaultGroup, db_strategy: :reset, type: :model do
  let(:default_group) { create(:group) }
  let(:other_group)   { create(:group) }
  let(:agent)         { create(:agent, groups: [default_group, other_group]) }
  let(:params)        { {} }
  let(:screen)        { 'create_middle' }
  let(:payload)       { { 'event' => 'core_workflow', 'request_id' => 'default', 'class_name' => 'Ticket', 'screen' => screen, 'params' => params } }
  let(:result)        { CoreWorkflow.perform(payload: payload, user: agent) }

  before do
    Wcl::Setup.default_group
    default_group.update!(wcl_default_group: true)
  end

  it 'starts a new ticket in the default group' do
    expect(result[:select]['group_id']).to eq(default_group.id.to_s)
  end

  context 'when a group was already picked' do
    let(:params) { { 'group_id' => other_group.id.to_s } }

    it 'keeps the picked group' do
      expect(result[:select]['group_id']).not_to eq(default_group.id.to_s)
    end
  end

  context 'when editing an existing ticket' do
    let(:screen) { 'edit' }

    it 'does not touch the group' do
      expect(result[:select]['group_id']).to be_nil
    end
  end

  context 'when the user may not create tickets in the default group' do
    let(:agent) { create(:agent, groups: [other_group]) }

    it 'does not preselect it' do
      expect(result[:select]['group_id']).not_to eq(default_group.id.to_s)
    end
  end

  it 'keeps only one default group' do
    other_group.update!(wcl_default_group: true)

    expect(Group.where(wcl_default_group: true)).to contain_exactly(other_group)
  end
end
