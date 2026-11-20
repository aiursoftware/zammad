# coffeelint: disable=camel_case_classes
class App.UiElement.group_permissions extends Spine.Module
  @render: (attribute, params = {}) ->
    groupsRaw      = App.Group.search(sortBy: 'name')
    groups         = groupsRaw.filter (elem) -> elem.active
    groupsSelected = groups.filter (elem) -> params.group_ids && !_.isEmpty(params.group_ids[elem.id])

    item = $(App.view('generic/user_permission_group')(
      params:         params
      groupsSelected: groupsSelected
      groupAccesses:  App.Group.accesses()
    ))

    @renderNewGroupDropdown(item, groups)
    @attachGroupsEvents(item, groups)

    # check/uncheck group permissions (particular permissions vs. full)
    item.on('click', '.checkbox-replacement', (event) ->
      App.PermissionHelper.switchGroupPermission(event)
    )

    item

  @renderNewGroupDropdown: (item, allGroups) ->
    selectedGroupIds = item
      .find('tr[data-id]')
      .toArray()
      .map (elem) -> parseInt elem.dataset.id

    filteredGroupIds = allGroups
      .filter (elem) -> !_.include(selectedGroupIds, elem.id)
      .map    (elem) -> elem.id.toString()

    attribute = {
      value:      ''
      nulloption: true,
      null:       true,
      relation:   'Group',
      filter:     filteredGroupIds
    }

    element = App.UiElement.ApplicationTreeSelect.render(attribute)

    item.find('.js-groupListItemAddNew').html(element)
    element.find('.js-shadow').trigger('change')

  @attachGroupsEvents: (item, groups) ->
    item
      .on('click', '.js-remove', (e) => @onRemoveGroup(e, item, groups))
      .on('click', '.js-add', (e) => @onAddGroup(e, item, groups))

    # WCL customization: the input row adds itself once a group and a permission are chosen.
    #   Its checkboxes carry no field name, so an input row nobody clicked "Add" on was
    #   silently dropped on Submit. Deferred, because the full/partial permission switch
    #   adjusts the checkboxes after the click.
    autoAdd = => setTimeout((=> @autoAddGroup(item, groups)), 0)
    item
      .on('click', '.js-groupListNewItemRow .checkbox-replacement', autoAdd)
      .on('change', '.js-groupListNewItemRow .js-shadow', autoAdd)

  @autoAddGroup: (item, groups) ->
    row = item.find('.js-groupListNewItemRow')
    return if !parseInt(row.find('.js-shadow').val())
    return if !row.find('.js-groupListItem:checked').length

    @addGroup(row, item, groups)

  @onRemoveGroup: (e, item, groups) ->
    e.stopPropagation()
    e.preventDefault()

    e.target
      .closest('tr')
      .remove()

    @renderNewGroupDropdown(item, groups)

  @onAddGroup: (e, item, groups) ->
    e.stopPropagation()
    e.preventDefault()

    @addGroup($(e.target.closest('tr')), item, groups)

  @addGroup: (row, item, groups) ->
    newGroupId = parseInt(row.find('.js-shadow').val())

    row.find('.js-input').toggleClass('has-error', !newGroupId)

    return if !newGroupId

    group      = _.find(groups, (elem) -> elem.id == newGroupId)
    shadowRow  = item.find('.js-groupListShadowItemRow')

    newRow = shadowRow
      .clone()
      .removeClass('hide js-groupListShadowItemRow')
      .attr('data-id', group.id)

    newRow.find('td:first-child').text(group.displayName())

    row
      .find('.js-groupListItem')
      .each((i, elem) ->
        isChecked = elem.checked
        value     = elem.value

        newRow
          .find(".js-groupListItem[value=#{value}]")
          .prop('checked', isChecked)
          .attr('name', "group_ids::#{newGroupId}")
      )
      .prop('checked', false)

    newRow.insertBefore(shadowRow)

    @renderNewGroupDropdown(item, groups)
