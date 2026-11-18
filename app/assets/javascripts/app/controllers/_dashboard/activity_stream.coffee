class App.DashboardActivityStream extends App.CollectionController
  model: false
  template: 'dashboard/activity_stream_item'
  uniqKey: 'id'
  observe:
    updated_at: true
  prepareForObjectListItemSupport: true
  items: []
  insertPosition: 'before'

  # WCL customization: filter bar (what / who / action / when / group + text search).
  #   Server-side filters narrow the permission-scoped stream; the text search runs on the
  #   loaded entries. The choice is remembered per user in local storage.
  filterStorageKey: 'wcl_activity_stream_filter'
  filterDefaults:
    object: ''
    actor:  ''
    action: ''
    since:  ''
    group:  ''
    text:   ''
  filterLimit: 100

  constructor: ->
    super
    @filter = _.extend({}, @filterDefaults, @filterLoad())
    @allItems = []
    @renderFilter()
    @fetch()

    # bind to rebuild view event
    @controllerBind('activity_stream_rebuild', @rebuild)

  # live updates arrive unfiltered: use them directly only when no server filter is set
  rebuild: (data) =>
    if @serverFilterActive()
      @delay(@fetch, 1000, 'activity_stream_filtered_refresh')
      return
    @load(data)

  fetch: =>
    if @serverFilterActive()
      @ajax(
        id:          'activity_stream_filtered'
        type:        'GET'
        url:         "#{@apiPath}/activity_stream?full=true"
        data:
          limit:  @filterLimit
          filter: @serverFilter()
        processData: true
        success: (data) =>
          @load(data, false)
      )
      return

    # use cache of first page
    cache = App.SessionStorage.get('activity_stream')
    if cache
      @load(cache)

    # init fetch via ajax, all other updates on time via websockets
    else
      @ajax(
        type:  'GET'
        url:   "#{@apiPath}/activity_stream?full=true"
        data:
          limit: @limit || 8
        processData: true
        success: (data) =>
          @load(data)
      )

  load: (data, cache = true) =>
    App.SessionStorage.set('activity_stream', data) if cache
    App.ActivityStream.refresh([], clear: true)
    App.Collection.loadAssets(data.assets)
    @allItems = App.ActivityStream.search(sortBy: 'created_at', order: 'DESC')
    @applyText()

  applyText: =>
    query = (@currentFilter().text || '').trim().toLowerCase()
    all = @allItems || []
    @items = if query then _.filter(all, (item) => @itemText(item).indexOf(query) isnt -1) else all
    @collectionSync(@items)
    @updateFilterStatus()

  itemText: (item) =>
    item = @prepareForObjectListItem(item)
    parts = [item.title, item.object_name, item.created_by?.displayName?()]
    if item.objectNative?.activityMessage
      parts.push $('<div>').html(item.objectNative.activityMessage(item)).text()
    _.compact(parts).join(' ').toLowerCase()

  itemGet: (key) =>
    for item in @items
      return item if key is item.id

  itemDestroy: (key) ->
    # nothing

  itemsAll: =>
    @items || []

  onRenderEnd: =>
    @el.closest('.sidebar').find('.activity-description').toggleClass('hidden', !_.isEmpty(@items) || @filterActive())
    @updateFilterStatus()

  onRenderItemEnd: (item, el) ->
    return if App.Session.get() is undefined

    new App.WidgetAvatar(
      el:        el.find('.js-avatar')
      object_id: item.created_by_id
      size:      40
    )

  # --- filter bar ---

  renderFilter: =>
    return if !@filterEl

    @filterEl.html(App.view('dashboard/activity_filter')(
      filter:  @filter
      active:  @filterActive()
      objects: [
        { value: '',             name: __('All') }
        { value: 'ticket',       name: __('Tickets') }
        { value: 'user',         name: __('People') }
        { value: 'organization', name: __('Organizations') }
        { value: 'admin',        name: __('Groups & roles') }
      ]
      actors: [
        { value: '',       name: __('Anyone') }
        { value: 'me',     name: __('Me') }
        { value: 'others', name: __('Teammates') }
        { value: 'people', name: __('People only (hide system)') }
        { value: 'system', name: __('System only') }
      ]
      actions: [
        { value: '',        name: __('All actions') }
        { value: 'create',  name: __('Created') }
        { value: 'update',  name: __('Updated') }
        { value: 'session', name: __('Signed in') }
      ]
      sinces: [
        { value: '',      name: __('Any time') }
        { value: 'today', name: __('Today') }
        { value: '7d',    name: __('Last 7 days') }
        { value: '30d',   name: __('Last 30 days') }
      ]
      groups: @filterGroups()
    ))

    @filterEl.off('.wclActivity')
    @filterEl.on('click.wclActivity', '.js-filterObject', (e) =>
      @setFilter(object: $(e.currentTarget).data('value') || '')
    )
    @filterEl.on('change.wclActivity', '.js-filterSelect', (e) =>
      change = {}
      change[e.currentTarget.name] = $(e.currentTarget).val() || ''
      @setFilter(change)
    )
    @filterEl.on('input.wclActivity', '.js-filterText', (e) =>
      @filter.text = $(e.currentTarget).val()
      @filterSave()
      @delay(@applyText, 200, 'activity_stream_text_filter')
    )
    @filterEl.on('click.wclActivity', '.js-filterReset', =>
      @filter = _.extend({}, @filterDefaults)
      @filterSave()
      @renderFilter()
      @fetch()
    )

  setFilter: (change) =>
    @filter = _.extend({}, @filter, change)
    @filterSave()
    @renderFilter()
    @fetch()

  updateFilterStatus: =>
    return if !@filterEl
    @filterEl.find('.js-filterReset').toggleClass('hide', !@filterActive())
    text = ''
    if @filterActive()
      text = if _.isEmpty(@items) then App.i18n.translatePlain('No activity matches these filters.') else App.i18n.translatePlain('%s shown', (@items || []).length)
    @filterEl.find('.js-filterCount').text(text)

  filterGroups: ->
    user = App.User.current()
    return [] if !user
    ids = user.allGroupIds('read')
    groups = _.filter(_.map(ids, (id) -> App.Group.findNative(id)), (group) -> group && group.active isnt false)
    _.sortBy(groups, (group) -> group.displayName())

  # the base class renders once before the constructor body sets @filter
  currentFilter: =>
    @filter || @filterDefaults

  serverFilter: =>
    _.pick(@currentFilter(), (value, key) -> key isnt 'text' and !_.isEmpty(String(value || '')))

  serverFilterActive: =>
    !_.isEmpty(@serverFilter())

  filterActive: =>
    @serverFilterActive() || !_.isEmpty((@currentFilter().text || '').trim())

  filterLoad: =>
    stored = App.LocalStorage.get(@filterStorageKey, App.Session.get('id'))
    if _.isObject(stored) then _.pick(stored, _.keys(@filterDefaults)) else {}

  filterSave: =>
    App.LocalStorage.set(@filterStorageKey, @filter, App.Session.get('id'))
