# WCL customization: the signed-in user's role names, shown on the dashboard and in the avatar menu.
class App.WclUserRoles
  @names: ->
    user = App.User.current()
    return [] if !user
    names = _.compact(_.map(user.role_ids || [], (id) -> App.Role.findNative(id)?.name if App.Role.exists(id)))
    _.sortBy(names, (name) -> name.toLowerCase())
