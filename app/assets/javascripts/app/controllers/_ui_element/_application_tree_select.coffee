# coffeelint: disable=camel_case_classes
class App.UiElement.ApplicationTreeSelect extends App.UiElement.ApplicationUiElement
  @render: (attributeConfig, params) ->
    attribute = $.extend(true, {}, attributeConfig)

    # set multiple option
    if attribute.multiple
      attribute.multiple = 'multiple'
    else
      attribute.multiple = ''

    # add deleted historical options if required
    @addDeletedOptions(attribute, params)

    # build options list based on config
    @getConfigOptionList(attribute, params)

    # build options list based on relation
    @getRelationOptionList(attribute, params)

    # add null selection if needed
    @addNullOption(attribute, params)

    # sort attribute.options
    @sortOptions(attribute, params)

    # find selected/checked item of list
    if attribute.options
      @optionsSelect(attribute.options, attribute.value)

    # disable item of list
    @disabledOptions(attribute, params)

    # filter attributes
    @filterOption(attribute, params)

    new App.SearchableSelect(attribute: attribute).element()

  @optionsSelect: (children, value) ->
    return if !children
    for child in children
      if child.value?.toString() is value?.toString()
        child.selected = true
      if child.children
        @optionsSelect(child.children, value)

  @filterTreeOptions: (attribute, valueDepth, options) ->
    newOptions = []
    nullFound = false
    for option, index in options
      enabled = _.contains(attribute.filter, option.value.toString())
      if attribute.null && !option.value && !nullFound
        nullFound = true
        enabled   = true

      activeChildren = false
      if option.value && option.children && option.children.length > 0
        if @isTreeRelation(attribute)
          if @hasActiveChildren(attribute, attribute.tree_children[option.value], attribute.filter)
            activeChildren = true
        else
          for value in attribute.filter
            if value && value.startsWith(option.value + '::')
              activeChildren = true

      if activeChildren
        option.inactive = !enabled
        option.children = @filterTreeOptions(attribute, valueDepth + 1, option.children)
      else
        option.children = undefined
        continue if !enabled

      newOptions.push(option)

    return newOptions

  @filterOptionArray: (attribute) ->
    attribute.options = @filterTreeOptions(attribute, 0, attribute.options)

    # WCL customization: a field whose filter leaves one branch (e.g. the ticket Category, which
    # lists only the chosen group's categories) shows that branch's entries directly.
    return if !attribute.flatten_single_branch
    branches = _.filter(attribute.options, (option) -> option.value)
    return if branches.length isnt 1 || !branches[0].inactive || _.isEmpty(branches[0].children)
    attribute.options = _.reject(attribute.options, (option) -> option is branches[0]).concat(branches[0].children)

  @buildOptionList: (list, attribute) ->
    return super if !@isTreeRelation(attribute)

    attribute.options = @buildOptionListTreeRelation(attribute, '-NONE-')
    attribute.sortBy  = null

  @buildOptionListTreeRelation: (attribute, parent_id) ->
    result = []
    return result if !attribute.tree_children[parent_id]

    for item in attribute.tree_children[parent_id]
      row = @buildOptionListRow(attribute, item)
      continue if !row

      children = @buildOptionListTreeRelation(attribute, item.id.toString())
      if children.length > 0
        row.children = children

      result.push row
    result
