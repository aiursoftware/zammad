# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: Admin > System > Backups. Makes, lists and deletes backups in the same folder
#   and format as the nightly zammad-backup container (deploy/linux), so either can restore them:
#
#   <timestamp>_zammad_db.psql.gz     the database (pg_dump)
#   <timestamp>_zammad_files.tar.gz   the file storage
#
# The folder is BACKUP_DIR, else /var/tmp/zammad (./backup on the server), else tmp/backup.
module Wcl::Backup
  FILE_PATTERN  = %r{\A(?<id>\d{14})_zammad_(?<kind>db\.psql|files\.tar)\.gz\z}
  ID_PATTERN    = %r{\A\d{14}\z}
  RUNNING_FILE  = '.wcl_backup_running'.freeze
  RUNNING_LIMIT = 6.hours

  class Error < StandardError; end

  def self.dir
    path = ENV['BACKUP_DIR'].presence || ('/var/tmp/zammad' if File.directory?('/var/tmp/zammad'))
    path = path ? Pathname.new(path) : Rails.root.join('tmp/backup')
    FileUtils.mkdir_p(path)
    path
  end

  # Newest first: [{ id:, created_at:, size:, database:, files: }]
  def self.list
    backups = {}
    dir.children.each do |path|
      match = FILE_PATTERN.match(path.basename.to_s)
      next if !match

      backup = backups[match[:id]] ||= { id: match[:id], created_at: path.mtime, size: 0, database: false, files: false }
      backup[:size] += path.size
      backup[match[:kind] == 'db.psql' ? :database : :files] = true
      backup[:created_at] = [backup[:created_at], path.mtime].min
    end
    backups.values.sort_by { |backup| backup[:id] }.reverse
  end

  def self.running?
    marker = dir.join(RUNNING_FILE)
    marker.exist? && marker.mtime > RUNNING_LIMIT.ago
  end

  def self.start!
    raise Error, __('A backup is already being made.') if running?

    FileUtils.touch(dir.join(RUNNING_FILE))
    WclBackupJob.perform_later
  end

  def self.create!
    id = Time.zone.now.in_time_zone(Setting.get('timezone_default').presence || 'UTC').strftime('%Y%m%d%H%M%S')
    FileUtils.touch(dir.join(RUNNING_FILE))

    write(dir.join("#{id}_zammad_files.tar.gz")) { |part| run!('tar', '-czf', part.to_s, '-C', storage_dir.dirname.to_s, storage_dir.basename.to_s) }
    write(dir.join("#{id}_zammad_db.psql.gz")) { |part| run!('bash', '-c', 'set -o pipefail; pg_dump --no-password "$@" | gzip > "$0"', part.to_s, *pg_dump_args, env: pg_env) }

    id
  ensure
    FileUtils.rm_f(dir.join(RUNNING_FILE))
  end

  def self.destroy!(id)
    raise Error, __('This backup does not exist.') if !ID_PATTERN.match?(id.to_s)

    files = dir.glob("#{id}_zammad_*.gz")
    raise Error, __('This backup does not exist.') if files.empty?

    files.each { |path| FileUtils.rm_f(path) }
  end

  # The file storage folder (as in the docker image: /opt/zammad/storage).
  def self.storage_dir
    path = Rails.root.join('storage')
    FileUtils.mkdir_p(path)
    path
  end

  def self.write(target)
    part = Pathname.new("#{target}.part")
    yield part
    File.rename(part, target)
  rescue
    FileUtils.rm_f(part)
    raise
  end

  def self.run!(*command, env: {})
    output, status = Open3.capture2e(env, *command)
    return if status.success?

    raise Error, "#{command.first} failed: #{output.strip.lines.last(5).join}"
  end

  def self.pg_config
    ActiveRecord::Base.connection_db_config.configuration_hash
  end

  def self.pg_dump_args
    config = pg_config
    args   = []
    args += ['--host', config[:host].to_s] if config[:host].present?
    args += ['--port', config[:port].to_s] if config[:port].present?
    args += ['--username', config[:username].to_s] if config[:username].present?
    args + [config[:database].to_s]
  end

  def self.pg_env
    pg_config[:password].present? ? { 'PGPASSWORD' => pg_config[:password].to_s } : {}
  end

  private_class_method :write, :run!, :pg_config, :pg_dump_args, :pg_env
end
