# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: public messages only.
RSpec.describe Ticket::Article::WclPublicOnly, type: :model do
  let(:agent)  { create(:agent) }
  let(:ticket) { create(:ticket) }

  before do
    Wcl::Setup.public_messages_only
    Setting.set(described_class::SETTING, true)
  end

  def as_web_user(&)
    ApplicationHandleInfo.use('application_server') do
      UserInfo.with_user_id(agent.id, &)
    end
  end

  it 'makes a note written in the web app public' do
    article = as_web_user { create(:ticket_article, ticket: ticket, internal: true) }

    expect(article.reload.internal).to be(false)
  end

  it 'does not let a message be switched to internal' do
    article = as_web_user { create(:ticket_article, ticket: ticket, internal: false) }
    as_web_user { article.update!(internal: true) }

    expect(article.reload.internal).to be(false)
  end

  it 'leaves notes made by the system alone' do
    article = create(:ticket_article, ticket: ticket, internal: true)

    expect(article.reload.internal).to be(true)
  end

  context 'when switched off' do
    before { Setting.set(described_class::SETTING, false) }

    it 'keeps internal notes' do
      article = as_web_user { create(:ticket_article, ticket: ticket, internal: true) }

      expect(article.reload.internal).to be(true)
    end
  end
end
