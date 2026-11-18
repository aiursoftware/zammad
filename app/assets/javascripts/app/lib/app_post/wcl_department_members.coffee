# WCL customization: Admin > Manage > Departments > People: see, add and remove a department's users.
class App.WclDepartmentMembers extends App.ControllerModal
  buttonClose: true
  buttonCancel: false
  buttonSubmit: __('Done')
  head: __('People')
  large: true
  shown: false
  events:
    'input .js-search': 'searchSoon'
    'click .js-add':    'add'
    'click .js-remove': 'remove'

  constructor: ->
    super
    @head       = App.i18n.translatePlain('People in %s', @department.name)
    @members    = []
    @candidates = []
    @query      = ''
    @load()

  url: (path = '') ->
    "#{@apiPath}/departments/#{@department.id}#{path}"

  load: =>
    @ajax(
      id:   "department_members_#{@department.id}"
      type: 'GET'
      url:  @url('/members')
      success: (data) =>
        @members = data
        if @shown then @refresh() else @render()
    )

  content: =>
    $(App.view('department/members')(members: @members, candidates: @candidates, query: @query))

  # Re-render but keep typing in the search box.
  refresh: =>
    focused = document.activeElement?.classList?.contains('js-search')
    @update()
    return if !focused
    input = @el.find('.js-search')
    input.trigger('focus')
    input[0]?.setSelectionRange(@query.length, @query.length)

  onShown: =>
    super
    @el.find('.js-search').trigger('focus')

  searchSoon: (e) =>
    @query = $(e.target).val()
    @delay(@search, 250, 'department_member_search')

  search: =>
    if @query.trim().length < 2
      @candidates = []
      @refresh()
      return
    @ajax(
      id:          "department_candidates_#{@department.id}"
      type:        'GET'
      url:         @url('/candidates')
      data:        { query: @query }
      processData: true
      success: (data) =>
        @candidates = data
        @refresh()
    )

  add: (e) =>
    e.preventDefault()
    userId = $(e.currentTarget).data('id')
    @ajax(
      id:   "department_add_#{userId}"
      type: 'POST'
      url:  @url('/members')
      data: JSON.stringify(user_id: userId)
      success: =>
        @candidates = _.reject(@candidates, (user) -> user.id is userId)
        @load()
    )

  remove: (e) =>
    e.preventDefault()
    userId = $(e.currentTarget).data('id')
    @ajax(
      id:   "department_remove_#{userId}"
      type: 'DELETE'
      url:  @url("/members/#{userId}")
      success: => @load()
    )

  onSubmit: =>
    @close()
