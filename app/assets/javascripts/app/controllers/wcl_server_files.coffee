# WCL customization: Admin > System > Server Files (see WclServerFilesController). Read-only:
#   browse the log files, the backups and the file storage, read the end of a text file and
#   download files.
class WclServerFiles extends App.ControllerSubContent
  @requiredPermission: 'admin.maintenance'
  header: __('Server Files')
  events:
    'click .js-root':     'selectRoot'
    'click .js-folder':   'openFolder'
    'click .js-crumb':    'openFolder'
    'click .js-view':     'viewFile'
    'click .js-close':    'closeViewer'
    'input .js-filter':   'filterLines'
    'click .js-refresh':  'refresh'

  ROOTS = [
    { key: 'logs',    name: __('Logs') }
    { key: 'backups', name: __('Backups') }
    { key: 'storage', name: __('Attachments') }
  ]

  constructor: ->
    super
    @root    = 'logs'
    @path    = ''
    @entries = []
    @viewer  = null
    @load()

  load: =>
    @ajax(
      id:   'wcl_server_files'
      type: 'GET'
      url:  "#{@apiPath}/wcl/server_files"
      data: { root: @root, path: @path }
      processData: true
      success: (data) =>
        @entries = data.entries || []
        @render()
      error: @showError
    )

  render: =>
    crumbs = [{ name: _.findWhere(ROOTS, key: @root).name, path: '' }]
    parts  = _.compact(@path.split('/'))
    for part, i in parts
      crumbs.push({ name: part, path: parts.slice(0, i + 1).join('/') })

    @html App.view('wcl_server_files/index')(
      roots:    ROOTS
      root:     @root
      crumbs:   crumbs
      entries:  @entries
      viewer:   @viewer
      download: (path) => "#{@apiPath}/wcl/server_files/download?root=#{encodeURIComponent(@root)}&path=#{encodeURIComponent(path)}"
    )
    @filterLines() if @viewer

  selectRoot: (e) =>
    e.preventDefault()
    @root   = $(e.currentTarget).data('root')
    @path   = ''
    @viewer = null
    @load()

  openFolder: (e) =>
    e.preventDefault()
    @path   = $(e.currentTarget).data('path').toString()
    @viewer = null
    @load()

  refresh: (e) =>
    e.preventDefault()
    if @viewer then @showFile(@viewer.path) else @load()

  viewFile: (e) =>
    e.preventDefault()
    @showFile($(e.currentTarget).data('path').toString())

  showFile: (path) =>
    @ajax(
      id:   'wcl_server_files_view'
      type: 'GET'
      url:  "#{@apiPath}/wcl/server_files/view"
      data: { root: @root, path: path }
      processData: true
      success: (data) =>
        @viewer = _.extend(data, path: path)
        @render()
        pre = @$('.js-content').get(0)
        pre.scrollTop = pre.scrollHeight if pre
      error: @showError
    )

  closeViewer: (e) =>
    e.preventDefault()
    @viewer = null
    @render()

  # Shows only the lines containing the filter text (case-insensitive).
  filterLines: =>
    return if !@viewer
    filter = (@$('.js-filter').val() || '').toLowerCase()
    lines  = @viewer.content.split('\n')
    lines  = _.filter(lines, (line) -> line.toLowerCase().indexOf(filter) isnt -1) if filter
    @$('.js-content').text(lines.join('\n'))
    @$('.js-lineCount').text(App.i18n.translatePlain('%s lines', lines.length))

  showError: (xhr) =>
    @notify(
      type:      'error'
      msg:       xhr.responseJSON?.error || __('Something went wrong.')
      removeAll: true
    )

App.Config.set('WclServerFiles', { prio: 3670, name: __('Server Files'), parent: '#system', target: '#system/server_files', controller: WclServerFiles, permission: ['admin.maintenance'] }, 'NavBarAdmin')
