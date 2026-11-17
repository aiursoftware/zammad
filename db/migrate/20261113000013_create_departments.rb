# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# WCL customization: Departments managed in Admin > Manage > Departments (see Department).
class CreateDepartments < ActiveRecord::Migration[7.2]
  def up
    if !table_exists?(:departments)
      create_table :departments, id: :integer do |t|
        t.string  :name,          limit: 200, null: false
        t.string  :email,         limit: 250, null: true
        t.string  :note,          limit: 250, null: true
        t.boolean :active,        null: false, default: true
        t.integer :updated_by_id, null: false
        t.integer :created_by_id, null: false
        t.timestamps limit: 3, null: false
      end
      add_index :departments, :name, unique: true
      add_foreign_key :departments, :users, column: :created_by_id
      add_foreign_key :departments, :users, column: :updated_by_id
      Department.reset_column_information
    end

    # return if it's a new setup (the seeds run HrPortal::Setup)
    return if !Setting.exists?(name: 'system_init_done')

    HrPortal::Setup.departments
  end

  def down
    drop_table :departments if table_exists?(:departments)
  end
end
