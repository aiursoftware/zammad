# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: the files employees may attach to their tickets in the HR app. Admins set
# them in Admin → Ticket → Settings → Base; the HR app reads them and checks every upload.
module HrPortal::AttachmentRules
  DEFAULT_EXTENSIONS = 'pdf, png, jpg, jpeg, gif, webp, heic, bmp, doc, docx, xls, xlsx, ppt, pptx, odt, ods, txt, csv, rtf, zip'.freeze

  SETTINGS = [
    {
      title:       __('HR app: allowed attachment types'),
      name:        'hr_portal_attachment_extensions',
      description: __('File extensions employees may attach to tickets in the HR app, separated by commas (e.g. "pdf, png, jpg"). Leave empty to turn attachments off.'),
      state:       DEFAULT_EXTENSIONS,
      prio:        9000,
    },
    {
      title:       __('HR app: maximum attachment size (MB)'),
      name:        'hr_portal_attachment_max_mb',
      description: __('The largest file, in megabytes, an employee may attach in the HR app. Note: one message with all its files must stay under the web server\'s request limit (about 28 MB on IIS by default).'),
      state:       '10',
      prio:        9010,
    },
    {
      title:       __('HR app: maximum attachments per message'),
      name:        'hr_portal_attachment_max_count',
      description: __('How many files an employee may attach to one message in the HR app.'),
      state:       '5',
      prio:        9020,
    },
  ].freeze

  def self.create_settings
    SETTINGS.each do |setting|
      Setting.create_if_not_exists(
        title:       setting[:title],
        name:        setting[:name],
        area:        'Ticket::Base',
        description: setting[:description],
        options:     { form: [{ display: '', null: true, name: setting[:name], tag: 'input' }] },
        preferences: { prio: setting[:prio], permission: ['admin.ticket'] },
        state:       setting[:state],
        frontend:    false,
      )
    end
  end

  # { extensions: ['.pdf', '.png'], max_bytes: 10485760, max_count: 5 }
  def self.current
    extensions = Setting.get('hr_portal_attachment_extensions').to_s
      .split(%r{[\s,;]+})
      .map { |ext| ".#{ext.strip.downcase.delete_prefix('.')}" }
      .reject { |ext| ext == '.' }
      .uniq
    max_mb    = Setting.get('hr_portal_attachment_max_mb').to_s.to_f
    max_count = Setting.get('hr_portal_attachment_max_count').to_s.to_i

    {
      extensions: extensions,
      max_bytes:  (max_mb.positive? ? max_mb : 10) * 1024 * 1024,
      max_count:  max_count.positive? ? max_count : 5,
    }.tap { |rules| rules[:max_bytes] = rules[:max_bytes].to_i }
  end
end
