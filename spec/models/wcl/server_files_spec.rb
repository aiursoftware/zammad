# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# WCL customization: Admin > System > Server Files.
RSpec.describe Wcl::ServerFiles do
  let(:dir) { Pathname.new(Dir.mktmpdir) }

  before do
    stub_const('ENV', ENV.to_h.merge('BACKUP_DIR' => dir.to_s))
    FileUtils.mkdir_p(dir.join('old'))
    File.write(dir.join('a.log'), "line one\nline two\n")
    File.write(dir.join('old', 'b.log'), 'older')
  end

  after { FileUtils.rm_rf(dir) }

  it 'lists a folder, folders first' do
    expect(described_class.list('backups').pluck(:name)).to eq(%w[old a.log])
  end

  it 'lists a subfolder' do
    expect(described_class.list('backups', 'old').pluck(:path)).to eq(['old/b.log'])
  end

  it 'shows a text file' do
    expect(described_class.view('backups', 'a.log')[:content]).to eq("line one\nline two\n")
  end

  it 'refuses paths outside the folder' do
    expect { described_class.list('backups', '../../etc') }.to raise_error(described_class::Error)
  end

  it 'refuses a link that points outside the folder' do
    File.symlink('/etc/hostname', dir.join('escape'))

    expect { described_class.view('backups', 'escape') }.to raise_error(described_class::Error)
  end

  it 'refuses an absolute path' do
    expect { described_class.view('backups', '//etc/hostname') }.to raise_error(described_class::Error)
  end

  it 'refuses a path with a NUL byte' do
    expect { described_class.view('backups', "a.log\0") }.to raise_error(described_class::Error)
  end

  it 'refuses unknown folders' do
    expect { described_class.list('config') }.to raise_error(described_class::Error)
  end

  it 'does not show binary files' do
    File.binwrite(dir.join('x.gz'), "\x1f\x8b\x00\x00")

    expect { described_class.view('backups', 'x.gz') }.to raise_error(described_class::Error)
  end
end
