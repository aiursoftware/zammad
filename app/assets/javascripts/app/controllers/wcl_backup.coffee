# WCL customization: Admin > System > Backups (see WclBackupsController).
class WclBackup extends App.ControllerSubContent
  @requiredPermission: 'admin.maintenance'
  header: __('Backups')
  events:
    'click .js-create':         'create'
    'click .js-delete':         'delete'
    'click .js-deleteSelected': 'deleteSelected'
    'change .js-selectAll':     'selectAll'
    'change .js-select':        'select'
    'click .js-row td:not(.table-checkbox):not(.wcl-backups-actions)': 'toggleRow'

  constructor: ->
    super
    @backups  = []
    @running  = false
    @selected = {}
    @fetch()

  release: =>
    @clearDelay('wcl_backup_poll')

  fetch: =>
    @ajax(
      id:      'wcl_backups'
      type:    'GET'
      url:     "#{@apiPath}/wcl/backups"
      success: @load
    )

  load: (data) =>
    wasRunning = @running
    @backups   = data.backups || []
    @running   = data.running

    # forget selections of backups that are gone
    ids       = _.pluck(@backups, 'id')
    @selected = _.pick(@selected, ids...)
    @render()

    if wasRunning && !@running
      @notify(type: 'success', msg: __('Backup finished.'), removeAll: true)

    @clearDelay('wcl_backup_poll')
    @delay(@fetch, 5000, 'wcl_backup_poll') if @running

  render: =>
    @html App.view('wcl_backup/index')(
      backups:  @backups
      running:  @running
      selected: @selected
    )
    @updateSelection()

  selectedIds: =>
    _.keys(@selected)

  updateSelection: =>
    count = @selectedIds().length
    total = @backups.length

    @$('.js-selectedCount').text(count)
    @$('.js-deleteSelected').toggleClass('hidden', count is 0)
    @$('.js-selectAll')
      .prop('checked', total > 0 && count is total)
      .prop('indeterminate', count > 0 && count < total)
    @$('.js-row').each (index, row) =>
      $(row).toggleClass('is-selected', !!@selected[$(row).data('id')])

  select: (e) =>
    id = $(e.currentTarget).val()
    if $(e.currentTarget).prop('checked')
      @selected[id] = true
    else
      delete @selected[id]
    @updateSelection()

  selectAll: (e) =>
    checked = $(e.currentTarget).prop('checked')
    @selected = {}
    if checked
      @selected[backup.id] = true for backup in @backups
    @$('.js-select').prop('checked', checked)
    @updateSelection()

  toggleRow: (e) ->
    checkbox = $(e.currentTarget).closest('.js-row').find('.js-select')
    checkbox.prop('checked', !checkbox.prop('checked')).trigger('change')

  deleteSelected: (e) =>
    e.preventDefault()
    ids = @selectedIds()
    return if !ids.length

    new App.ControllerConfirm(
      message:     App.i18n.translatePlain('Delete %s backups? This cannot be undone.', ids.length)
      buttonClass: 'btn--danger'
      container:   @el.closest('.content')
      callback: =>
        @ajax(
          id:          'wcl_backups_delete_many'
          type:        'POST'
          url:         "#{@apiPath}/wcl/backups/delete"
          data:        JSON.stringify(ids: ids)
          processData: true
          success: (data) =>
            @selected = {}
            @notify(type: 'success', msg: App.i18n.translatePlain('%s backups deleted.', ids.length), removeAll: true)
            @load(data)
          error: @showError
        )
    )

  create: (e) =>
    e.preventDefault()
    @ajax(
      id:      'wcl_backups_create'
      type:    'POST'
      url:     "#{@apiPath}/wcl/backups"
      success: (data) =>
        @notify(type: 'success', msg: __('Backup started. This can take a few minutes.'), removeAll: true)
        @load(data)
      error: @showError
    )

  delete: (e) =>
    e.preventDefault()
    id = $(e.currentTarget).data('id')

    new App.ControllerConfirm(
      message:     __('Delete this backup? This cannot be undone.')
      buttonClass: 'btn--danger'
      container:   @el.closest('.content')
      callback: =>
        @ajax(
          id:      'wcl_backups_delete'
          type:    'DELETE'
          url:     "#{@apiPath}/wcl/backups/#{id}"
          success: (data) =>
            @notify(type: 'success', msg: __('Backup deleted.'), removeAll: true)
            @load(data)
          error: @showError
        )
    )

  showError: (xhr) =>
    @notify(
      type:      'error'
      msg:       xhr.responseJSON?.error || __('Something went wrong.')
      removeAll: true
    )

App.Config.set('WclBackup', { prio: 3650, name: __('Backups'), parent: '#system', target: '#system/backups', controller: WclBackup, permission: ['admin.maintenance'] }, 'NavBarAdmin')
