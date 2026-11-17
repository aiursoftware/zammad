# WCL customization: "Assign users by domain" for Admin > Organizations (see Wcl::DomainAssignment).
class App.WclDomainAssignment
  @run: (container, organization) ->
    message = if organization
      App.i18n.translatePlain('Put every user with an email ending in @%s and no organization into %s?', organization.domain, organization.name)
    else
      App.i18n.translatePlain('Put every user without an organization into the organization matching their email domain? Only organizations with "Domain based assignment" switched on are used.')

    new App.ControllerConfirm(
      head:        __('Assign users by domain')
      message:     message
      buttonClass: 'btn--success'
      buttonSubmit: __('Assign')
      container:   container
      callback:    => @assign(organization)
    )

  @assign: (organization) ->
    App.Ajax.request(
      id:          'wcl_domain_assignment'
      type:        'POST'
      url:         "#{App.Config.get('api_path')}/wcl/organizations/assign_by_domain"
      data:        JSON.stringify(if organization then { organization_id: organization.id } else {})
      processData: true
      success: (data) ->
        msg = if data.total is 0
          App.i18n.translatePlain('No users to assign: everyone with a matching email already has an organization.')
        else
          details = ("#{name}: #{count}" for name, count of data.assigned when count > 0).join(', ')
          App.i18n.translatePlain('%s users assigned (%s).', data.total, details)
        App.Event.trigger('notify', { type: 'success', msg: msg, timeout: 6000 })
      error: (xhr) ->
        details = xhr.responseJSON || {}
        App.Event.trigger('notify', { type: 'error', msg: details.error_human || details.error || __('The users could not be assigned.'), timeout: 6000 })
    )
