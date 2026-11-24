# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: "Accept email only from existing users".
RSpec.describe Channel::Filter::WclBlockUnknownSenders, type: :channel_filter do
  let(:known)  { create(:customer, email: 'known@example.com') }
  let(:raw)    { <<~MAIL }
    From: #{from}
    To: support@example.com
    Cc: stranger-cc@example.com
    Subject: Printer broken

    It does not print.
  MAIL
  let(:from)   { 'Stranger <stranger@example.com>' }
  let(:result) { Channel::EmailParser.new.process({}, raw) }

  before do
    Wcl::Setup.email_only_existing_users
    Setting.set(Wcl::UnknownEmailSenders::SETTING, true)
  end

  context 'when the sender has no account' do
    it 'creates no ticket' do
      expect { result }.not_to change(Ticket, :count)
    end

    it 'creates no user' do
      expect { result }.not_to change(User, :count)
    end
  end

  context 'when the sender has an account' do
    let(:from) { "Known <#{known.email}>" }

    before { known }

    it 'creates the ticket for them' do
      expect(result.first.customer).to eq(known)
    end

    it 'does not add the Cc address as a user' do
      expect { result }.not_to change(User, :count)
    end
  end

  context 'when the sender uses different letter case' do
    let(:from) { 'Known <KNOWN@Example.com>' }

    before { known }

    it 'still accepts the email' do
      expect(result.first.customer).to eq(known)
    end
  end

  context 'when switched off' do
    before { Setting.set(Wcl::UnknownEmailSenders::SETTING, false) }

    it 'creates the sender as usual' do
      expect { result }.to change(Ticket, :count).by(1)
    end
  end

  context 'when the address is blocked' do
    let(:from) { "Known <#{known.email}>" }

    before do
      known
      Setting.set(Wcl::UnknownEmailSenders::SETTING, false)
      Wcl::UnknownEmailSenders.block!('KNOWN@example.com')
    end

    it 'drops the email even for an existing user' do
      expect { result }.not_to change(Ticket, :count)
    end
  end

  context 'when a user is deleted with "Block their email address?"' do
    let(:user) { create(:customer, email: 'leaver@example.com') }

    it 'adds their address to the blocked list' do
      create(:data_privacy_task, deletable: user, preferences: { block_email: 'true' }).perform

      expect(Wcl::UnknownEmailSenders.blocked).to include('leaver@example.com')
    end

    it 'leaves the list alone when not asked to' do
      create(:data_privacy_task, deletable: user, preferences: { block_email: 'false' }).perform

      expect(Wcl::UnknownEmailSenders.blocked).to be_empty
    end
  end
end
