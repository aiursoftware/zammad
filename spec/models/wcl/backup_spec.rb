# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: Admin > System > Backups.
RSpec.describe Wcl::Backup, performs_jobs: true do
  let(:dir) { Pathname.new(Dir.mktmpdir) }

  before { stub_const('ENV', ENV.to_h.merge('BACKUP_DIR' => dir.to_s)) }
  after  { FileUtils.rm_rf(dir) }

  def make(id, kinds = %w[db.psql files.tar])
    kinds.each { |kind| File.write(dir.join("#{id}_zammad_#{kind}.gz"), 'x' * 10) }
  end

  describe '.list' do
    before do
      make('20261101030000')
      make('20261102030000', %w[db.psql])
      File.write(dir.join('notes.txt'), 'ignored')
    end

    it 'lists backups newest first' do
      expect(described_class.list.pluck(:id)).to eq(%w[20261102030000 20261101030000])
    end

    it 'tells what each backup holds' do
      expect(described_class.list.first).to include(database: true, files: false, size: 10)
    end
  end

  describe '.destroy!' do
    before do
      make('20261101030000')
      make('20261102030000')
    end

    it 'deletes both files of the backup' do
      described_class.destroy!('20261101030000')

      expect(dir.children.map { |path| path.basename.to_s }).to all(start_with('20261102030000'))
    end

    it 'refuses anything that is not a backup id' do
      expect { described_class.destroy!('../../etc') }.to raise_error(Wcl::Backup::Error)
    end

    it 'refuses a backup that does not exist' do
      expect { described_class.destroy!('20200101000000') }.to raise_error(Wcl::Backup::Error)
    end
  end

  describe '.destroy_many!' do
    before do
      make('20261101030000')
      make('20261102030000')
      make('20261103030000')
    end

    it 'deletes the selected backups only' do
      described_class.destroy_many!(%w[20261101030000 20261102030000])

      expect(described_class.list.pluck(:id)).to eq(%w[20261103030000])
    end

    it 'refuses when one of them is not a backup' do
      expect { described_class.destroy_many!(%w[20261101030000 ../../etc]) }.to raise_error(Wcl::Backup::Error)
    end

    it 'then deletes none of them' do
      begin
        described_class.destroy_many!(%w[20261101030000 ../../etc])
      rescue Wcl::Backup::Error
        nil
      end

      expect(described_class.list.size).to eq(3)
    end
  end

  describe '.create!' do
    it 'writes the database and the file storage' do
      id = described_class.create!

      expect(described_class.list.first).to include(id: id, database: true, files: true)
    end

    it 'is no longer running afterwards' do
      described_class.create!

      expect(described_class).not_to be_running
    end
  end

  describe '.start!' do
    it 'queues the backup' do
      expect { described_class.start! }.to have_enqueued_job(WclBackupJob)
    end

    it 'refuses a second one while the first runs' do
      described_class.start!

      expect { described_class.start! }.to raise_error(Wcl::Backup::Error)
    end
  end
end
