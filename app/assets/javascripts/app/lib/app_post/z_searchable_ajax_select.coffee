class App.SearchableAjaxSelect extends App.SearchableSelect
  constructor: ->
    super

    # create cache
    @searchResultCache = {}

  render: ->
    if not _.isEmpty(@attribute.value) and not @attribute.multiple
      @attribute.options = [] if not _.isArray(@attribute.options)

      if @attribute.relation
        if App[@attribute.relation] && App[@attribute.relation].exists(@attribute.value)
          displayName = App[@attribute.relation].find(@attribute.value).displayName()
          @attribute.options.push({ value: @attribute.value, name: displayName, selected: true })
      else
        @attribute.options.push({ value: @attribute.value, name: @attribute.valueName or @attribute.value, selected: true })

    super

  objectString: =>
    # convert requested object
    # e.g. Ticket to ticket or AnotherObject to another_object
    return underscored(@options.attribute.relation)

  # WCL: organizations and users are listed as soon as the field opens, so they can be picked
  #   without typing; the search backend reads "*" as "everything".
  browsable: =>
    @options.attribute.relation in ['Organization', 'User']

  searchQuery: =>
    query = @input.val()
    return query if !@browsable()
    return '*' if !query?.trim() || (!@options.attribute.multiple && query is @options.attribute.valueName)
    query

  onDropdownShown: =>
    super
    @search() if @browsable()

  cacheKey: =>
    objectString = @objectString()
    query        = @searchQuery()

    # create cache key
    return "#{objectString}+#{query}"

  ajaxAttributes: =>
    objectString = @objectString()
    query        = @searchQuery()
    cacheKey     = @cacheKey()

    {
      id:   @options.attribute.id
      type: 'POST'
      url:  "#{App.Config.get('api_path')}/search/#{objectString}"
      data: JSON.stringify(query: query, limit: @options.attribute.limit)
      processData: true
      success:     (data, status, xhr) =>
        # cache search result
        @searchResultCache[cacheKey] = data
        @renderResponse(data, query)
      error: =>
        @hideLoader()
    }

  hideLoader: =>
    # Clear timeout and remove the loader icon.
    clearTimeout @loaderTimeoutId
    @loaderTimeoutId = undefined
    @el.removeClass('is-loading')

  onInput: (event) =>
    super
    @search()

  search: =>
    query    = @searchQuery()
    cacheKey = @cacheKey()

    # use cache for search result
    if @searchResultCache[cacheKey]
      App.Ajax.abort @options.attribute.id
      @renderResponse @searchResultCache[cacheKey], query
      return

    # add timeout for loader icon
    if !@loaderTimeoutId
      @loaderTimeoutId = setTimeout @showLoader, 1000

    attributes = @ajaxAttributes()

    # if delegate is given and provides getAjaxAttributes method, try to extend ajax call
    # this is needed for autocompletion field in KB answer-to-answer linking to submit search context
    if @delegate?.getAjaxAttributes
      attributes = @delegate?.getAjaxAttributes?(@, attributes)

    # start search request and update options
    App.Ajax.request(attributes)

  renderResponse: (data, originalQuery) =>
    @hideLoader()

    # load assets
    App.Collection.loadAssets(data.assets)

    # get options from search result
    options = data
      .result
      .map (elem) =>
        # use search results directly to avoid loading KB assets in Ticket view
        if @useAjaxDetails
          @renderResponseItemAjax(elem, data)
        else
          @renderResponseItem(elem)
      .filter (elem) -> elem?

    # fill template with gathered options
    @optionsList.html @renderOptions options

    # refresh elements
    @refreshElements()

    @filterByQuery('')

  renderResponseItemAjax: (elem, data) ->
    result = _.find(data.details, (detailElem) -> detailElem.type == elem.type and detailElem.id == elem.id)

    # The details are escaped HTML, while the option template escapes what it is given.
    category = undefined
    if result.type is 'KnowledgeBase::Answer::Translation' && result.subtitle
      category = App.Utils.html2text(result.subtitle)
    if result
      {
        category: category
        name:     App.Utils.html2text(result.title)
        value:    elem.id
      }

  renderResponseItem: (elem) ->
    object = App[elem.type.replace(/::/g, '')]?.find(elem.id)

    if !object
      return

    name = if object instanceof App.Ticket
             "##{object.number} - #{object.title}"
           else
             object.displayName()

    {
      name:  name
      value: object.id
      inactive: !@options.attribute.allowInactive && object.active == false
    }

  showLoader: =>
    @el.addClass('is-loading')
