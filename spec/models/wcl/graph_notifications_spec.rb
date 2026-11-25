# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: notifications through the Microsoft 365 Graph account.
RSpec.describe Wcl::GraphNotifications do
  let(:graph)        { create(:microsoft_graph_channel, microsoft_user: 'support@wcl.example.com') }
  let(:notification) { Channel.find_by(area: 'Email::Notification', active: true) }

  before do
    Wcl::Setup.notifications_via_graph
    Setting.set('notification_sender', 'WCL Support <noreply@zammad.example.com>')
  end

  describe '.channel' do
    context 'when switched on with a Graph account' do
      before do
        graph
        Setting.set(described_class::SETTING, true)
      end

      it 'picks the Graph account' do
        expect(described_class.channel).to eq(graph)
      end
    end

    context 'when switched on without a Graph account' do
      before { Setting.set(described_class::SETTING, true) }

      it 'picks none, so the notification account is used' do
        expect(described_class.channel).to be_nil
      end
    end

    context 'when switched off' do
      before do
        graph
        Setting.set(described_class::SETTING, false)
      end

      it 'picks none' do
        expect(described_class.channel).to be_nil
      end
    end

    context 'with several Graph accounts' do
      let!(:sender_mailbox) { create(:microsoft_graph_channel, microsoft_user: 'noreply@zammad.example.com') }

      before do
        graph
        Setting.set(described_class::SETTING, true)
      end

      it 'prefers the one sending as the Notification Sender' do
        expect(described_class.channel).to eq(sender_mailbox)
      end
    end
  end

  describe '.sender' do
    it "keeps the Notification Sender's name with the Graph mailbox's address" do
      expect(described_class.sender(graph)).to eq('WCL Support <support@wcl.example.com>')
    end
  end

  describe 'NotificationFactory::Mailer.deliver' do
    let(:recipient) { create(:agent) }

    before do
      graph
      Setting.set(described_class::SETTING, true)
    end

    it 'sends through the Graph account as its mailbox' do
      expect_any_instance_of(Channel).to receive(:deliver).with(include(from: 'WCL Support <support@wcl.example.com>'), true)

      NotificationFactory::Mailer.deliver(recipient: recipient, subject: 'Hi', body: 'Hello')
    end
  end
end
