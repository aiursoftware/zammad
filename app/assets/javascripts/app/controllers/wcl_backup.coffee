# WCL customization: Admin > System > Backups (see WclBackupsController).
class WclBackup extends App.ControllerSubContent
  @requiredPermission: 'admin.maintenance'
  header: __('Backups')
  events:
    'click .js-create': 'create'
    'click .js-delete': 'delete'

  constructor: ->
    super
    @backups = []
    @running = false
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
    @render()

    if wasRunning && !@running
      @notify(type: 'success', msg: __('Backup finished.'), removeAll: true)

    @clearDelay('wcl_backup_poll')
    @delay(@fetch, 5000, 'wcl_backup_poll') if @running

  render: =>
    @html App.view('wcl_backup/index')(
      backups: @backups
      running: @running
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
