# WCL customization: the signed-in user's role names, shown on the dashboard and in the avatar menu.
class App.WclUserRoles
  @names: ->
    user = App.User.current()
    return [] if !user
    names = _.compact(_.map(user.role_ids || [], (id) -> App.Role.findNative(id)?.name if App.Role.exists(id)))

    # Users who aren't agents get "Role_<id>" instead of the real names (Role::Assets).
    names = _.reject(names, (name) -> /^Role_\d+$/.test(name))
    names = [App.i18n.translatePlain('Customer')] if !names.length && user.permission('ticket.customer')

    _.sortBy(names, (name) -> name.toLowerCase())
