# coffeelint: disable=camel_case_classes
class App.UiElement.timer
  @render: (attributeConfig) ->
    attribute = $.extend(true, {}, attributeConfig)

    days =
      Mon: __('Monday')
      Tue: __('Tuesday')
      Wed: __('Wednesday')
      Thu: __('Thursday')
      Fri: __('Friday')
      Sat: __('Saturday')
      Sun: __('Sunday')
    hours =
      0: '12 am'
      1: '1 am'
      2: '2 am'
      3: '3 am'
      4: '4 am'
      5: '5 am'
      6: '6 am'
      7: '7 am'
      8: '8 am'
      9: '9 am'
      10: '10 am'
      11: '11 am'
      12: '12 am'
      13: '1 pm'
      14: '2 pm'
      15: '3 pm'
      16: '4 pm'
      17: '5 pm'
      18: '6 pm'
      19: '7 pm'
      20: '8 pm'
      21: '9 pm'
      22: '10 pm'
      23: '11 pm'
    hours =
      0: '00'
      1: '01'
      2: '02'
      3: '03'
      4: '04'
      5: '05'
      6: '06'
      7: '07'
      8: '08'
      9: '09'
      10: '10'
      11: '11'
      12: '12'
      13: '13'
      14: '14'
      15: '15'
      16: '16'
      17: '17'
      18: '18'
      19: '19'
      20: '20'
      21: '21'
      22: '22'
      23: '23'
    minutes =
      0: '00'
      10: '10'
      20: '20'
      30: '30'
      40: '40'
      50: '50'

    if !attribute.value
      attribute.value = {}
    if _.isEmpty(attribute.value.days)
      attribute.value.days =
        Mon: true
    if _.isEmpty(attribute.value.hours)
      attribute.value.hours =
        0: true
    if _.isEmpty(attribute.value.minutes)
      attribute.value.minutes =
        0: true

    # WCL customization: minutes outside the 10-minute buttons (e.g. 24, 32), typed in a field
    exactMinutes = _.sortBy(
      (parseInt(minute, 10) for minute, active of attribute.value.minutes when active and parseInt(minute, 10) % 10 isnt 0),
      (minute) -> minute
    )

    timer = $( App.view('generic/timer')( attribute: attribute, days: days, hours: hours, minutes: minutes, exactMinutes: exactMinutes ) )
    timer.find('.js-boolean').data('field-type', 'boolean')
    timer.find('.select-value').on('click', (e) =>
      @select(e)
    )
    timer.find('.js-exactMinutes').on('change', (e) =>
      @exactMinutesChanged(e)
    )
    @createOutputString(timer)

    timer

  @select: (e) =>
    target = $(e.currentTarget)

    if target.hasClass('is-selected')
      # prevent zero selections (exact minutes count as a selection too)
      exactMinutes = target.closest('.select-boxes').find('.js-exactMinutesValues input').length
      if target.siblings('.is-selected').length > 0 || (target.data('type') is 'minute' && exactMinutes > 0)
        target.removeClass('is-selected')
        target.next().val('false')
    else
      target.addClass('is-selected')
      target.next().val('true')

    formGroup = $(e.currentTarget).closest('.form-group')
    @createOutputString(formGroup)

  # Typed minutes: round ones select their button, the others are kept as exact minutes.
  @exactMinutesChanged: (e) =>
    input     = $(e.currentTarget)
    box       = input.closest('.js-minute')
    name      = input.data('attribute-name')
    tokens    = _.compact(input.val().split(/[^0-9]+/))
    values    = _.uniq((parseInt(token, 10) for token in tokens))
    invalid   = _.filter(values, (minute) -> _.isNaN(minute) || minute < 0 || minute > 59)
    input.closest('.timer-exact').toggleClass('has-error', invalid.length > 0)
    values    = _.sortBy(_.difference(values, invalid), (minute) -> minute)

    exact = []
    for minute in values
      if minute % 10 is 0
        button = box.find("[data-type=minute][data-value=#{minute}]")
        button.addClass('is-selected')
        button.next().val('true')
      else
        exact.push minute

    container = box.find('.js-exactMinutesValues').empty()
    for minute in exact
      hidden = $('<input type="hidden" class="js-boolean" value="true">').attr('name', "#{name}::minutes::#{minute}")
      hidden.data('field-type', 'boolean')
      container.append(hidden)

    # keep at least one minute: fall back to :00 when everything was cleared
    if exact.length is 0 && box.find('[data-type=minute].is-selected').length is 0
      button = box.find('[data-type=minute][data-value=0]')
      button.addClass('is-selected')
      button.next().val('true')

    input.val(_.map(exact, (minute) -> minute.toString()).join(', '))
    @createOutputString(input.closest('.form-group'))

  @createOutputString: (formGroup) =>
    days = $.map(formGroup.find('[data-type=day]').filter('.is-selected'), (el) -> return $(el).text() )
    hours = $.map(formGroup.find('[data-type=hour]').filter('.is-selected'), (el) -> return $(el).text() )
    minutes = $.map(formGroup.find('[data-type=minute]').filter('.is-selected'), (el) -> return $(el).text() )
    exact = $.map(formGroup.find('.js-exactMinutesValues input'), (el) -> return $(el).attr('name').split('::').pop() )
    minutes = _.sortBy(_.uniq(minutes.concat(_.map(exact, (minute) -> if minute.length is 1 then "0#{minute}" else minute))), (minute) -> parseInt(minute, 10))

    hours = @injectMinutes(hours, minutes)

    days = @joinItems days
    hours = @joinItems hours
    timezone = App.Config.get('timezone_default')

    formGroup.find('.js-timerResult').html(App.i18n.translateInline('Run every %s at %s in %s time', days, hours, timezone))

  @injectMinutes: (hours, minutes) ->
    newHours = [] # hours.length x minutes.length long

    for hour in hours
      # split off am/pm
      [hour, suffix] = hour.split(' ')

      for minute in minutes
        combined = "#{ hour }:#{ minute }"
        combined += " #{suffix}" if suffix

        newHours.push combined

    newHours

  @joinItems: (items) ->
    switch items.length
      when 1 then return items[0]
      when 2 then return "#{ items[0] } #{App.i18n.translateInline('and')} #{ items[1] }"
      else
        return "#{ items.slice(0, -1).join(', ') } #{App.i18n.translateInline('and')} #{ items[items.length-1] }"
