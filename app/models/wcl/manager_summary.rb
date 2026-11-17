# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: a weekly summary email to every active user with the Manager role, so they
# can follow their teams without logging in. Each manager gets last week's Maintenance report
# (Wcl::MaintenanceReport, Monday to Sunday) for the groups they can see, with the Excel file
# attached. Sent on Monday morning by the scheduler 'WCL: weekly summary to managers' when the
# setting 'wcl_manager_summary' (Admin > Settings > Ticket > Base) is on.
#
# Sent through the notification email channel, like Zammad's own notifications.
class Wcl::ManagerSummary
  SETTING = 'wcl_manager_summary'.freeze

  def self.deliver_all(force: false)
    return 0 if !force && !Setting.get(SETTING)

    recipients.count { |user| new(user).deliver }
  end

  def self.recipients
    role = Role.find_by(name: Wcl::Setup::MANAGER_ROLE)
    return [] if !role

    role.users.where(active: true).where.not(email: [nil, '']).to_a
  end

  attr_reader :user, :report

  def initialize(user, today: nil)
    timezone = Setting.get('timezone_default').presence || 'UTC'
    today  ||= Time.current.in_time_zone(timezone).to_date
    monday   = today.beginning_of_week(:monday) - 1.week

    @user   = user
    @report = Wcl::MaintenanceReport.new(user: user, from: monday, to: monday + 6.days, timezone: timezone)
  end

  def deliver
    return false if report.data[:groups].empty?

    file = report.file
    NotificationFactory::Mailer.deliver(
      recipient:    user,
      subject:      subject,
      body:         body,
      content_type: 'text/html',
      attachments:  [{ filename: report.filename, content: file.read, mime_type: Wcl::MaintenanceReport::CONTENT_TYPE }],
    )
    true
  rescue => e
    Rails.logger.error "WCL weekly summary to #{user.email} failed: #{e.message}"
    false
  ensure
    file&.close
  end

  def subject
    "Weekly ticket summary #{report.from.strftime('%d %b')} - #{report.to.strftime('%d %b %Y')}"
  end

  def body # rubocop:disable Metrics/AbcSize
    data    = report.data
    summary = data[:summary]
    rows = [
      ['Submitted',                summary[:submitted]],
      ['Completed',                summary[:completed]],
      ['Rejected',                 summary[:rejected]],
      [__('Outstanding now'),          summary[:outstanding_now]],
      [__('Avg. completion (days)'),   summary[:average_days] || '-'],
      [__('Oldest open ticket'),       oldest_text(data[:oldest_open])],
    ]

    <<~HTML
      <div style="font-family: Arial, sans-serif; font-size: 14px;">
        <p>Hello #{h(user.firstname.presence || user.fullname)},</p>
        <p>Tickets for <b>#{h(data[:groups].join(', '))}</b>, #{h(report.from.strftime('%a %d %b'))} to #{h(report.to.strftime('%a %d %b %Y'))}:</p>
        #{table(%w[Measure Value], rows)}
        #{section(__('Per person'), ['Person', 'Completed', __('Open now'), __('Avg. days')], data[:by_person].map { |row| [row[:name], row[:completed], row[:open_now], row[:average_days] || '-'] })}
        #{section(__('Repeat issues (same category at the same location)'), %w[Location Category Tickets Numbers], data[:repeats].map { |row| [row[:location], row[:category], row[:count], row[:tickets]] })}
        <p>The full report is attached (Excel). Any period: <a href="#{h(report_url)}">Maintenance Report</a>.</p>
        <p style="color: #888; font-size: 12px;">Sent every Monday to managers. An admin can switch it off in Admin &gt; Settings &gt; Ticket &gt; Base.</p>
      </div>
    HTML
  end

  private

  def oldest_text(oldest)
    return '-' if !oldest

    "##{oldest[:number]} #{oldest[:title]} (#{oldest[:days_open]} days, #{oldest[:owner]})"
  end

  def section(title, headers, rows)
    return '' if rows.empty?

    "<h3 style=\"margin: 18px 0 6px;\">#{h(title)}</h3>#{table(headers, rows)}"
  end

  def table(headers, rows)
    cell = 'style="border: 1px solid #ccc; padding: 4px 10px; text-align: left;"'
    head = headers.map { |header| "<th #{cell}>#{h(header)}</th>" }.join
    body = rows.map { |row| "<tr>#{row.map { |value| "<td #{cell}>#{h(value)}</td>" }.join}</tr>" }.join
    "<table style=\"border-collapse: collapse;\"><tr style=\"background: #eee;\">#{head}</tr>#{body}</table>"
  end

  def report_url
    "#{Setting.get('http_type')}://#{Setting.get('fqdn')}/#maintenance_report"
  end

  def h(value)
    ERB::Util.html_escape(value.to_s)
  end
end
