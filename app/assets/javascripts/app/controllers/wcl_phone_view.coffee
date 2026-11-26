# WCL customization: Admin > System > Phone View. Shows the mobile app (/mobile) at the screen
#   size of a chosen phone, so admins can check how it looks for staff without the device.
#   The device list is shared by all admins (setting wcl_phone_view_devices).
class WclPhoneView extends App.ControllerSubContent
  @requiredPermission: 'admin.maintenance'
  header: __('Phone View')
  events:
    'change .js-device':        'selectDevice'
    'click .js-rotate':         'rotate'
    'click .js-reload':         'reload'
    'click .js-removeDevice':   'removeDevice'
    'submit .js-addDevice':     'addDevice'

  SETTING   = 'wcl_phone_view_devices'
  STORE_KEY = 'wcl-phone-view-device'

  constructor: ->
    super
    @landscape   = false
    @subscribeId = App.Setting.subscribe(@render, initFetch: true, clear: false)

  release: =>
    App.Setting.unsubscribe(@subscribeId)

  devices: ->
    list = App.Config.get(SETTING)
    if _.isArray(list) then list else []

  currentIndex: ->
    devices = @devices()
    return 0 if !devices.length
    index = parseInt(App.LocalStorage.get(STORE_KEY) || 0)
    if index >= 0 && index < devices.length then index else 0

  render: =>
    devices = @devices()
    index   = @currentIndex()
    device  = devices[index]

    width  = device?.width || 384
    height = device?.height || 824
    [width, height] = [height, width] if @landscape

    @html App.view('wcl_phone_view/index')(
      devices:   devices
      index:     index
      width:     width
      height:    height
      landscape: @landscape
      url:       "#{App.Config.get('http_type')}://#{App.Config.get('fqdn')}/mobile"
    )
    @fitToSpace()

  # Scales the phone down when it is taller than the window, so it is shown whole.
  fitToSpace: =>
    frame = @$('.js-phone')
    return if !frame.length
    available = $(window).height() - frame.offset().top - 40
    scale     = Math.min(1, available / frame.outerHeight())
    frame.css('transform', "scale(#{scale})")
    @$('.js-phoneHolder').css('height', frame.outerHeight() * scale)

  selectDevice: (e) =>
    App.LocalStorage.set(STORE_KEY, $(e.currentTarget).val())
    @landscape = false
    @render()

  rotate: (e) =>
    e.preventDefault()
    @landscape = !@landscape
    @render()

  reload: (e) =>
    e.preventDefault()
    frame = @$('.js-frame').get(0)
    frame.src = frame.src if frame

  removeDevice: (e) =>
    e.preventDefault()
    index   = parseInt($(e.currentTarget).data('index'))
    devices = @devices().slice()
    return if devices.length <= 1
    devices.splice(index, 1)
    App.LocalStorage.set(STORE_KEY, 0)
    @saveDevices(devices)

  addDevice: (e) =>
    e.preventDefault()
    params = @formParam(e.target)
    name   = $.trim(params.name || '')
    width  = parseInt(params.width)
    height = parseInt(params.height)

    if !name || !(width >= 240 && width <= 1400) || !(height >= 320 && height <= 2000)
      @notify(
        type: 'error'
        msg:  __('Enter a name, a width between 240 and 1400 and a height between 320 and 2000.')
      )
      return

    devices = @devices().concat([{ name: name, width: width, height: height }])
    App.LocalStorage.set(STORE_KEY, devices.length - 1)
    @saveDevices(devices)

  saveDevices: (devices) =>
    App.Setting.set(SETTING, devices, notify: true, doneLocal: @render)

App.Config.set('WclPhoneView', { prio: 3660, name: __('Phone View'), parent: '#system', target: '#system/phone_view', controller: WclPhoneView, permission: ['admin.maintenance'] }, 'NavBarAdmin')
