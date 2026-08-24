class CreateProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :description, null: false, default: ""
      t.string :status, null: false, default: "active"
      t.timestamps null: false
    end

    add_index :projects, :name, unique: true
    add_index :projects, :code, unique: true
    add_index :projects, :status
    add_check_constraint :projects, "status IN ('active', 'paused', 'completed')", name: "projects_status_check"
  end
end