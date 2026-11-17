class Department extends App.ControllerSubContent
  @requiredPermission: 'admin.user'
  header: __('Departments')
  constructor: ->
    super

    @genericController = new App.ControllerGenericIndex(
      el: @el
      id: @id
      genericObject: 'Department'
      defaultSortBy: 'name'
      pageData:
        home: 'departments'
        object: __('Department')
        objects: __('Departments')
        searchPlaceholder: __('Search for departments')
        navupdate: '#departments'
        buttons: [
          { name: __('New Department'), 'data-type': 'new', class: 'btn--success' }
        ]
      container: @el.closest('.content')
    )

App.Config.set('Department', { prio: 1100, name: __('Departments'), parent: '#manage', target: '#manage/departments', controller: Department, permission: ['admin.user'] }, 'NavBarAdmin')
