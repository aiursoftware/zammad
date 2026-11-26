# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: the ticket's Department.
RSpec.describe Ticket::StampsDepartment, type: :model do
  let(:customer) { create(:customer) }
  let(:ticket)   { create(:ticket, customer: customer) }

  before do
    Wcl::Setup.ticket_department_attribute
    Ticket.reset_column_information
  end

  it "takes the requester's department when the ticket is created" do
    customer.update!(department: 'Warehouse') if customer.has_attribute?(:department)

    expect(create(:ticket, customer: customer).department).to eq(customer[:department].presence)
  end

  it 'does not count an empty Department from the form as a change' do
    ticket.update!(department: nil)
    ticket.update!(department: '', title: 'changed')

    expect(ticket.saved_changes).not_to have_key('department')
  end

  it 'keeps the Department empty instead of storing ""' do
    ticket.update!(department: '')

    expect(ticket.reload.department).to be_nil
  end
end
