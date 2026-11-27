# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: Admin > System > Server Files. Read-only look at three folders on the server:
#   the log files, the backups and the file storage (attachments, when Admin > System > Storage is
#   "Filesystem"). Nothing outside them can be reached: every path is resolved (symlinks included)
#   and must stay inside its folder.
module Wcl::ServerFiles
  ROOTS      = %w[logs backups storage].freeze
  VIEW_BYTES = 200.kilobytes
  MAX_LIST   = 1000

  class Error < StandardError; end

  def self.root_path(root)
    path = case root.to_s
           when 'logs'    then Rails.root.join('log')
           when 'backups' then Wcl::Backup.dir
           when 'storage' then Rails.root.join('storage')
           else raise Error, __('This folder is not available.')
           end
    FileUtils.mkdir_p(path)
    Pathname.new(File.realpath(path))
  end

  # The real path of `path` inside the root, or an error if it leaves the root or doesn't exist.
  def self.resolve(root, path)
    base   = root_path(root)
    target = base.join(path.to_s.delete_prefix('/'))
    raise Error, __('This file does not exist.') if !target.exist?

    real = Pathname.new(File.realpath(target))
    raise Error, __('This file does not exist.') if real != base && !real.to_s.start_with?("#{base}/")

    real
  rescue ArgumentError # e.g. a NUL byte in the path
    raise Error, __('This file does not exist.')
  end

  # The folders and files in a folder, folders first, then newest first.
  def self.list(root, path = '')
    base = root_path(root)
    dir  = resolve(root, path)
    raise Error, __('This is not a folder.') if !dir.directory?

    entries = dir.children.filter_map do |child|
      next if !child.exist?

      stat = child.stat
      {
        name:       child.basename.to_s,
        path:       child.relative_path_from(base).to_s,
        directory:  child.directory?,
        size:       child.directory? ? nil : stat.size,
        updated_at: stat.mtime,
      }
    end

    entries.sort_by { |e| [e[:directory] ? 0 : 1, -e[:updated_at].to_i] }.first(MAX_LIST)
  end

  # The end of a text file (the last VIEW_BYTES), for reading logs in the browser.
  def self.view(root, path)
    file = resolve(root, path)
    raise Error, __('This is not a file.') if !file.file?

    size = file.size
    data = File.open(file, 'rb') do |f|
      f.seek([size - VIEW_BYTES, 0].max)
      f.read(VIEW_BYTES)
    end
    raise Error, __('This file is not text and can only be downloaded.') if data.to_s.include?("\0")

    data = data.to_s.force_encoding('UTF-8').scrub
    data = data.sub(%r{\A[^\n]*\n}, '') if size > VIEW_BYTES # drop the cut-off first line

    { name: file.basename.to_s, size: size, truncated: size > VIEW_BYTES, content: data }
  end

  def self.file(root, path)
    file = resolve(root, path)
    raise Error, __('This is not a file.') if !file.file?

    file
  end
end
