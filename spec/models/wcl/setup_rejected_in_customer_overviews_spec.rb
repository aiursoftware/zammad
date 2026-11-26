# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: rejected requests stay in the employee's own lists.
RSpec.describe Wcl::Setup, '.rejected_in_customer_overviews', type: :model do
  let(:rejected) { Ticket::State.find_by(name: 'rejected') }
  let(:overview) { Overview.find_by(link: 'my_tickets') }
  let(:customer) { create(:customer) }

  def state_ids
    overview.reload.condition.dig('ticket.state_id', 'value').map(&:to_i)
  end

  before do
    described_class.rejected_state

    # as on an install from before this fix: My Tickets without Rejected
    condition = overview.condition.deep_dup
    condition['ticket.state_id']['value'] = state_ids - [rejected.id]
    overview.update!(condition: condition)

    described_class.rejected_in_customer_overviews
  end

  it 'adds Rejected to My Tickets' do
    expect(state_ids).to include(rejected.id)
  end

  it "lists a rejected request in the customer's My Tickets" do
    ticket = create(:ticket, customer: customer, state: rejected)

    expect(Ticket::Overviews.tickets_for_overview(overview.reload, customer).pluck(:id)).to include(ticket.id)
  end

  it 'can run again without adding it twice' do
    described_class.rejected_in_customer_overviews

    expect(state_ids.count(rejected.id)).to eq(1)
  end
end
