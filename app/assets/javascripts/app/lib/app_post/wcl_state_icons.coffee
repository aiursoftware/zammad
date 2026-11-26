# WCL customization: the ticket State and Priority dropdowns show an icon (from Zammad's own icon
#   set) in front of each option. A native dropdown can't show icons, so a small list is drawn on
#   top of it; the native select stays in the form (hidden) and keeps the value, so saving, form
#   rules (Core Workflow) and change events work as before.
class App.WclStateIcons
  # name or type => [icon, colour modifier]
  BY_NAME =
    'new':              ['plus',              'new']
    'open':             ['one-ticket',        'open']
    'in progress':      ['in-process',        'progress']
    'on hold':          ['stopwatch',         'hold']
    'pending reminder': ['clock',             'pending']
    'pending close':    ['checkmark-outline', 'pending']
    'closed':           ['checkmark',         'closed']
    'rejected':         ['diagonal-cross',    'rejected']
    'merged':           ['chain',             'merged']
    'removed':          ['trash',             'merged']

  BY_TYPE =
    'new':              BY_NAME['new']
    'open':             BY_NAME['open']
    'pending reminder': BY_NAME['pending reminder']
    'pending action':   BY_NAME['pending close']
    'closed':           BY_NAME['closed']
    'merged':           BY_NAME['merged']
    'removed':          BY_NAME['removed']

  PRIORITY_BY_NAME =
    '1 low':    ['low-priority', 'low']
    '2 normal': ['minus',        'normal']
    '3 high':   ['important',    'high']
    '4 urgent': ['important',    'urgent']

  # field => the model its options come from
  FIELDS =
    state_id:    'TicketState'
    priority_id: 'TicketPriority'

  @stateIcon: (stateId) ->
    state = App.TicketState.findNative(stateId) if stateId
    return if !state
    name = (state.name || '').toLowerCase()
    return BY_NAME[name] if BY_NAME[name]
    type = App.TicketStateType.findNative(state.state_type_id)
    BY_TYPE[(type?.name || '').toLowerCase()]

  # By name, else by the priority's own icon/colour (Admin > Priorities), else the normal one.
  @priorityIcon: (priorityId) ->
    priority = App.TicketPriority.findNative(priorityId) if priorityId
    return if !priority
    name = (priority.name || '').toLowerCase()
    return PRIORITY_BY_NAME[name] if PRIORITY_BY_NAME[name]
    return ['low-priority', 'low'] if priority.ui_icon is 'low-priority'
    return ['important', 'high'] if priority.ui_icon is 'important'
    PRIORITY_BY_NAME['2 normal']

  @iconFor: (field, id) ->
    if field is 'priority_id' then @priorityIcon(id) else @stateIcon(id)

  @iconHtml: (field, id) ->
    icon = @iconFor(field, id)
    return '<span class="wcl-state-icon wcl-state-icon--none"></span>' if !icon
    "<span class=\"wcl-state-icon wcl-state-icon--#{icon[1]}\">#{App.Utils.icon(icon[0])}</span>"

  # The ticket's saved value of the field, when the form edits an existing ticket (ticket sidebar).
  @savedValue: (params, field) ->
    return if !params?.id
    ticket = App.Ticket.findNative(params.id)
    ticket?[field]

  # Called with the rendered select element of a field.
  @enhance: (item, attribute, params) ->
    field = attribute.name
    return if !FIELDS[field]
    return if attribute.relation isnt FIELDS[field]
    return if attribute.multiple

    select = item.find('select')
    return if !select.length

    item.addClass('wcl-state-select')
    toggle = $('<button type="button" class="form-control wcl-state-toggle" aria-haspopup="listbox"></button>')
    menu   = $('<ul class="wcl-state-menu" role="listbox"></ul>').hide()
    notice = $('<div class="wcl-state-unsaved-note" role="status"></div>').hide()
    select.after(toggle, menu, notice)

    refresh = =>
      option = select.find('option:selected')
      label  = App.Utils.htmlEscape(option.text() || '-')
      toggle.html("#{@iconHtml(field, select.val())}<span class=\"wcl-state-label\">#{label}</span>#{App.Utils.icon('arrow-down', 'wcl-state-arrow')}")
      toggle.prop('disabled', select.prop('disabled'))
      @markUnsaved(item, notice, field, select.val(), @savedValue(params, field))

    close = ->
      menu.hide()
      $(document).off('mousedown.wclState keydown.wclState')

    open = =>
      menu.empty()
      select.find('option').each (index, option) =>
        $option = $(option)
        row = $("<li role=\"option\" class=\"wcl-state-option\" data-value=\"#{App.Utils.htmlEscape(option.value)}\"></li>")
        row.html("#{@iconHtml(field, option.value)}<span>#{App.Utils.htmlEscape($option.text())}</span>")
        row.addClass('is-selected') if option.selected
        row.addClass('is-disabled') if option.disabled
        menu.append(row)
      menu.show()
      $(document).on('mousedown.wclState', (e) ->
        return if $(e.target).closest(item).length
        close()
      )
      $(document).on('keydown.wclState', (e) ->
        close() if e.key is 'Escape'
      )

    toggle.on('click', (e) ->
      e.preventDefault()
      if menu.is(':visible') then close() else open()
    )
    menu.on('mousedown', '.wcl-state-option', (e) ->
      e.preventDefault()
      row = $(e.currentTarget)
      return if row.hasClass('is-disabled')
      select.val(row.data('value').toString()).trigger('change')
      close()
    )

    select.on('change', refresh)

    # The ticket is saved or changed elsewhere: compare against its new state.
    #   Unsubscribes once the form has been replaced (every re-render makes a new one).
    if params?.id
      key = App.Ticket.subscribeItem(params.id, ->
        if !document.body.contains(item.get(0))
          App.Ticket.unsubscribeItem(params.id, key)
          return
        refresh()
      )
    # Form rules may swap the options or the value without a change event.
    if window.MutationObserver
      new MutationObserver(refresh).observe(select.get(0), { childList: true, subtree: true, attributes: true })

    refresh()

  # An unsaved change (e.g. kept from before a page reload) is shown in orange with the value the
  #   ticket really has, until it is saved with Update or discarded.
  @markUnsaved: (item, notice, field, currentId, savedId) ->
    unsaved = savedId && currentId && currentId.toString() isnt savedId.toString()
    item.toggleClass('wcl-state-unsaved', !!unsaved)
    if !unsaved
      notice.hide()
      return

    saved = App[FIELDS[field]].findNative(savedId)
    name  = if saved then App.i18n.translatePlain(saved.name) else '-'
    notice.text(App.i18n.translatePlain('Not saved – currently: %s', name)).show()
