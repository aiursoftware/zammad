class App.Department extends App.Model
  @configure 'Department', 'name', 'email', 'note', 'active', 'updated_by', 'created_by'
  @extend Spine.Model.Ajax
  @url: @apiPath + '/departments'

  @configure_attributes = [
    { name: 'name',       display: __('Name'),   tag: 'input', type: 'text',  limit: 200, 'null': false },
    { name: 'email',      display: __('Email'),  tag: 'input', type: 'email', limit: 250, 'null': true },
    { name: 'note',       display: __('Note'),   tag: 'input', type: 'text',  limit: 250, 'null': true },
    { name: 'active',     display: __('Active'), tag: 'active', default: true },
    { name: 'updated_at', display: __('Updated'), tag: 'datetime', readonly: 1 },
  ]

  @configure_delete = true
  @configure_overview = [
    'name',
    'email',
    'note',
  ]

  @description = __('''
The departments of your company. The **Department** of a user (and of a ticket) is picked from the active departments here.

Renaming a department renames it on its users and tickets. Set a department inactive to stop offering it; users keep it.
''')
