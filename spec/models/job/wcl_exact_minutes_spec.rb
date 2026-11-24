# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: admin schedulers run at the exact minute picked, with catch-up.
RSpec.describe Job, 'exact minutes', type: :model do
  let(:monday) { Time.use_zone(Setting.get('timezone_default').presence || 'UTC') { Time.zone.parse('2026-11-23 01:00:00') } }
  let(:job) do
    create(:job, active: true, timeplan: { days: { Mon: true }, hours: { 1 => true }, minutes: { 24 => true, 32 => true } })
  end

  it 'is due at the exact minutes picked', :aggregate_failures do
    expect(job.in_timeplan?(monday.change(min: 24))).to be(true)
    expect(job.in_timeplan?(monday.change(min: 32, sec: 40))).to be(true)
    expect(job.in_timeplan?(monday.change(min: 23, sec: 59))).to be(false)
  end

  it 'still runs when the check comes a few minutes late' do
    expect(job.in_timeplan?(monday.change(min: 27))).to be(true)
  end

  it 'gives up on a run missed by more than the catch-up window' do
    job.update_column(:timeplan, { days: { Mon: true }, hours: { 1 => true }, minutes: { 24 => true } })
    expect(job.reload.in_timeplan?(monday.change(min: 40))).to be(false)
  end

  it 'runs only once for each planned minute', :aggregate_failures do
    job.update_column(:last_run_at, monday.change(min: 24, sec: 5))
    expect(job.reload.in_timeplan?(monday.change(min: 26))).to be(false)
    expect(job.in_timeplan?(monday.change(min: 32))).to be(true)
  end

  it 'plans the next run at the exact minute' do
    travel_to(monday.change(min: 25)) do
      job.save!
      expect(job.next_run_at).to eq(monday.change(min: 32))
    end
  end

  it 'keeps 10-minute slots for system schedulers' do
    calculation = TimeplanCalculation.new({ days: { Mon: true }, hours: { 1 => true }, minutes: { 20 => true } }, Setting.get('timezone_default'))
    expect(calculation.contains?(monday.change(min: 27))).to be(true)
  end
end
