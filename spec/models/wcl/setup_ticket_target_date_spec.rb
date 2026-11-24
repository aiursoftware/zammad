# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: optional "Target date" on tickets.
RSpec.describe Wcl::Setup, '.ticket_target_date', db_strategy: :reset, type: :model do
  before { described_class.ticket_target_date }

  let(:attribute) { ObjectManager::Attribute.get(object: 'Ticket', name: 'target_date') }

  it 'is a date field' do
    expect(attribute).to have_attributes(data_type: 'date')
  end

  it 'is optional on the new-ticket form for employees and agents' do
    expect(attribute.screens['create_middle']).to include(
      'ticket.customer' => include('shown' => true, 'required' => false),
      'ticket.agent'    => include('shown' => true, 'required' => false),
    )
  end

  it 'stores the date on the ticket' do
    ticket = create(:ticket, target_date: Date.new(2026, 12, 5))

    expect(ticket.reload.target_date).to eq(Date.new(2026, 12, 5))
  end

  it 'leaves tickets without one valid' do
    expect(create(:ticket).target_date).to be_nil
  end

  it 'can run again' do
    expect { described_class.ticket_target_date }.not_to raise_error
  end
end
