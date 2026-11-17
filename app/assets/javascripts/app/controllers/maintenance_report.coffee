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

  column: (key, label) ->
    { key: key, label: App.i18n.translateInline(label) }

  renderResult: (data) ->
    average = @column('average_days', __('Avg. completion (days)'))
    breakdown = [
      @column('name', __('Name')), @column('submitted', __('Submitted')), @column('completed', __('Completed')),
      @column('still_open', __('Still open')), average
    ]
    period = (label) => [@column('period', label), @column('submitted', __('Submitted')), @column('completed', __('Completed')), average]
    tables = [
      { title: App.i18n.translateInline('By week'), rows: data.by_week, columns: period(__('Week')) }
      { title: App.i18n.translateInline('By month'), rows: data.by_month, columns: period(__('Month')) }
      { title: App.i18n.translateInline('By department'), rows: data.by_department, columns: breakdown }
      { title: App.i18n.translateInline('By location'), rows: data.by_location, columns: breakdown }
      { title: App.i18n.translateInline('By category'), rows: data.by_category, columns: breakdown }
      { title: App.i18n.translateInline('By person'), rows: data.by_person, columns: [@column('name', __('Person')), @column('completed', __('Completed')), @column('open_now', __('Open now')), average] }
      { title: App.i18n.translateInline('Repeat issues (same category at the same location)'), rows: data.repeats, columns: [@column('location', __('Location')), @column('category', __('Category')), @column('count', __('Tickets')), @column('still_open', __('Still open')), @column('tickets', __('Ticket numbers'))] }
    ]
    summary = data.summary
    cards = [
      { label: App.i18n.translateInline('Submitted'), value: summary.submitted }
      { label: App.i18n.translateInline('Completed'), value: summary.completed }
      { label: App.i18n.translateInline('Rejected'), value: summary.rejected }
      { label: App.i18n.translateInline('Outstanding now'), value: summary.outstanding_now }
      { label: App.i18n.translateInline('Avg. completion (days)'), value: if summary.average_days? then summary.average_days else '–' }
    ]
    if data.oldest_open
      cards.push { label: App.i18n.translateInline('Oldest open (days)'), value: data.oldest_open.days_open, hint: "##{data.oldest_open.number} #{data.oldest_open.title}" }
    @$('.js-result').html App.view('maintenance_report/result')(cards: cards, tables: tables)

  download: (e) =>
    e.preventDefault()
    window.location.href = "#{@apiPath}/wcl/reports/maintenance?#{@query()}&sheet=true"

App.Config.set('maintenance_report', MaintenanceReport, 'Routes')
App.Config.set('MaintenanceReport', { prio: 8100, parent: '', name: __('Maintenance Report'), translate: true, target: '#maintenance_report', icon: 'tools', permission: ['report'] }, 'NavBarRight')
