class CreateTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :tasks do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description, null: false, default: ""
      t.string :state, null: false, default: "todo"
      t.string :priority, null: false, default: "medium"
      t.date :due_on
      t.timestamps null: false
    end

    add_index :tasks, :state
    add_index :tasks, :priority
    add_index :tasks, :due_on
    add_check_constraint :tasks, "state IN ('todo', 'in_progress', 'done')", name: "tasks_state_check"
    add_check_constraint :tasks, "priority IN ('low', 'medium', 'high')", name: "tasks_priority_check"
  end
end