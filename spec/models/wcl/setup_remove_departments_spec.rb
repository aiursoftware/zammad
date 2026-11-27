# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: no departments.
RSpec.describe Wcl::Setup, type: :model do
  describe '.remove_departments', db_strategy: :reset do
    let(:user_attribute) { ObjectManager::Attribute.get(object: 'User', name: 'department') }
    let(:customer)       { create(:customer, department: 'Warehouse') }
    let(:overview) do
      create(:overview, link: 'wcl_team_open', group_by: 'department',
                        view: { 'd' => %w[number title department], 's' => %w[number department], 'm' => %w[number], 'view_mode_default' => 's' })
    end

    before do
      ObjectManager::Attribute.add(
        force: true, object: 'Ticket', name: 'department', display: 'Department', data_type: 'input',
        data_option: { type: 'text', maxlength: 200, null: true }, editable: true, active: true,
        screens: {}, position: 33, created_by_id: 1, updated_by_id: 1
      )
      ObjectManager::Attribute.migration_execute
      user_attribute.update_columns(data_type: 'tree_select', data_option: { 'options' => [], 'null' => true })
      customer
      overview

      described_class.remove_departments
    end

    it 'removes the ticket field' do
      expect(Ticket.column_names).not_to include('department')
    end

    it 'takes the column out of overviews' do
      expect(overview.reload).to have_attributes(
        view:     include('d' => %w[number title], 's' => %w[number], 'm' => %w[number]),
        group_by: nil,
      )
    end

    it 'hides the user field as a plain text field' do
      expect(user_attribute.reload).to have_attributes(data_type: 'input', active: false)
    end

    it "keeps the users' values" do
      expect(customer.reload.department).to eq('Warehouse')
    end

    it 'can run again' do
      expect { described_class.remove_departments }.not_to raise_error
    end
  end
end
