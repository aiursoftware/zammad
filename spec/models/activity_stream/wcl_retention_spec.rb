# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: Admin > Dashboard > "Keep activities for".
RSpec.describe ActivityStream, 'retention', type: :model do
  def entry_at(time)
    described_class.create!(
      activity_stream_type_id:   TypeLookup.by_name('update'),
      activity_stream_object_id: ObjectLookup.by_name('Ticket'),
      o_id:                      1,
      permission_id:             Permission.find_by(name: 'ticket.agent').id,
      created_by_id:             1,
      created_at:                time,
      updated_at:                time,
    )
  end

  before { Wcl::Setup.activity_stream_retention }

  it 'keeps 90 days by default', :aggregate_failures do
    old    = entry_at(100.days.ago)
    recent = entry_at(80.days.ago)

    described_class.cleanup

    expect(described_class.exists?(old.id)).to be(false)
    expect(described_class.exists?(recent.id)).to be(true)
  end

  it 'follows the chosen number of days', :aggregate_failures do
    Setting.set(described_class::RETENTION_SETTING, 7)
    old    = entry_at(8.days.ago)
    recent = entry_at(6.days.ago)

    described_class.cleanup

    expect(described_class.exists?(old.id)).to be(false)
    expect(described_class.exists?(recent.id)).to be(true)
  end

  it 'still accepts an explicit age' do
    Setting.set(described_class::RETENTION_SETTING, 365)
    old = entry_at(10.days.ago)

    described_class.cleanup(5.days)

    expect(described_class.exists?(old.id)).to be(false)
  end
end
