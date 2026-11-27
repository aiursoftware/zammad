# WCL customization: Reporting > Maintenance Report (see Wcl::MaintenanceReport).
class MaintenanceReport extends App.ControllerAppContent
  @requiredPermission: 'report'
  events:
    'submit .js-form':    'show'
    'click .js-download': 'download'

  constructor: ->
    super
    @navupdate '#maintenance_report'
    @title __('Maintenance Report'), true
    @render()
    @show()

  render: ->
    today = new Date()
    pad = (number) -> String(number).padStart(2, '0')
    iso = (date) -> "#{date.getFullYear()}-#{pad(date.getMonth() + 1)}-#{pad(date.getDate())}"
    groups = _.sortBy(App.Group.search(filter: { active: true }), (group) -> group.name.toLowerCase())
    maintenance = _.find(groups, (group) -> group.name is 'Maintenance')
    @html App.view('maintenance_report/index')(
      from:            iso(new Date(today.getFullYear(), today.getMonth(), 1))
      to:              iso(today)
      groups:          groups
      selectedGroupId: maintenance?.id
    )

  query: ->
    timezone = App.Config.get('timezone_default')
    if !timezone
      try
        timezone = Intl.DateTimeFormat().resolvedOptions().timeZone
      catch
        timezone = ''
    query = $.param(
      from:     @$('[name=from]').val()
      to:       @$('[name=to]').val()
      timezone: timezone
    )
    groupId = @$('[name=group_id]').val()
    query += "&group_ids[]=#{encodeURIComponent(groupId)}" if groupId
    query

  show: (e) =>
    e?.preventDefault()
    @ajax(
      id:      'maintenance_report'
      type:    'GET'
      url:     "#{@apiPath}/wcl/reports/maintenance?#{@query()}"
      success: (data) => @renderResult(data)
    )

  column: (key, label, options = {}) ->
    _.extend({ key: key, label: App.i18n.translateInline(label) }, options)

  table: (title, rows, columns, options = {}) ->
    max = {}
    for column in columns when column.bar
      max[column.key] = _.max(_.map(rows, (row) -> row[column.key] or 0)) or 0
    _.extend({ title: App.i18n.translateInline(title), rows: rows or [], columns: columns, max: max, empty: App.i18n.translateInline('Nothing in this period.') }, options)

  # Under a day reads better in hours ("5 hours" rather than "0.2 days").
  formatDuration: (days) ->
    return '–' if !days?
    if days < 1
      hours = Math.max(1, Math.round(days * 24))
      return if hours is 1 then App.i18n.translatePlain('1 hour') else App.i18n.translatePlain('%s hours', hours)
    if days is 1 then App.i18n.translatePlain('1 day') else App.i18n.translatePlain('%s days', days)

  formatDate: (iso) ->
    App.i18n.translateDate(iso)

  renderResult: (data) ->
    average   = @column('average_days', __('Avg. days'), numeric: true)
    submitted = @column('submitted', __('Submitted'), numeric: true, bar: true)
    completed = @column('completed', __('Completed'), numeric: true)
    stillOpen = @column('still_open', __('Still open'), numeric: true)
    breakdown = (label) => [@column('name', label), submitted, completed, stillOpen, average]
    period    = (label) => [@column('period', label), submitted, completed, average]

    tables = [
      @table(__('By location'), data.by_location, breakdown(__('Location')))
      @table(__('By category'), data.by_category, breakdown(__('Category')))
      @table(__('By person'), data.by_person, [@column('name', __('Person')), @column('completed', __('Completed'), numeric: true, bar: true), @column('open_now', __('Open now'), numeric: true), average])
      @table(__('Repeat issues'), data.repeats, [@column('location', __('Location')), @column('category', __('Category')), @column('count', __('Tickets'), numeric: true, bar: true), @column('still_open', __('Still open'), numeric: true), @column('tickets', __('Ticket numbers'))],
        className: "wcl-panel--wide #{if data.repeats?.length then 'wcl-panel--alert' else ''}"
        hint:      App.i18n.translateInline('The same category reported at the same location more than once.')
        empty:     App.i18n.translateInline('No repeat issues in this period.')
      )
      @table(__('By week'), data.by_week, period(__('Week')))
      @table(__('By month'), data.by_month, period(__('Month')))
    ]

    summary  = data.summary
    outcome  = summary.outcome or { completed: 0, rejected: 0, open: 0 }
    total    = summary.submitted or 0
    percent  = (value) -> if total then Math.round(value * 100 / total) else 0
    flow = [
      { key: 'completed', label: App.i18n.translateInline('Completed'), value: outcome.completed, percent: percent(outcome.completed) }
      { key: 'rejected', label: App.i18n.translateInline('Rejected'), value: outcome.rejected, percent: percent(outcome.rejected) }
      { key: 'open', label: App.i18n.translateInline('Still open'), value: outcome.open, percent: percent(outcome.open) }
    ]

    groups = if data.groups?.length then data.groups.join(', ') else App.i18n.translateInline('your groups')
    from   = @formatDate(data.period.from)
    to     = @formatDate(data.period.to)
    text   = if total is 0
      App.i18n.translatePlain('No requests were submitted between %s and %s in %s.', from, to, groups)
    else
      App.i18n.translatePlain('%s requests submitted between %s and %s in %s.', total, from, to, groups)

    oldest = data.oldest_open
    kpis = [
      { label: App.i18n.translateInline('Submitted'), value: total }
      { label: App.i18n.translateInline('Completed'), value: summary.completed, note: App.i18n.translateInline('closed in this period') }
      { label: App.i18n.translateInline('Rejected'), value: summary.rejected }
      { label: App.i18n.translateInline('Outstanding now'), value: summary.outstanding_now, note: App.i18n.translateInline('open today, any date') }
      { label: App.i18n.translateInline('Avg. completion'), value: @formatDuration(summary.average_days) }
      { label: App.i18n.translateInline('Oldest open'), value: (if oldest then @formatDuration(Math.max(oldest.days_open, 1)) else '–'), note: (if oldest then "##{oldest.number} #{oldest.title}"), link: (if oldest then "#ticket/zoom/#{oldest.id}") }
    ]

    @$('.js-result').html App.view('maintenance_report/result')(
      lead:      { text: text, submitted: total }
      flow:      flow
      flowLabel: _.map(flow, (part) -> "#{part.label} #{part.value}").join(', ')
      kpis:      kpis
      tables:    tables
    )

  download: (e) =>
    e.preventDefault()
    window.location.href = "#{@apiPath}/wcl/reports/maintenance?#{@query()}&sheet=true"

App.Config.set('maintenance_report', MaintenanceReport, 'Routes')
App.Config.set('MaintenanceReport', { prio: 8100, parent: '', name: __('Maintenance Report'), translate: true, target: '#maintenance_report', icon: 'tools', permission: ['report'] }, 'NavBarRight')
