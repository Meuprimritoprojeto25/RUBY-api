class CreateActivityEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :activity_events do |t|
      t.references :project, null: false, foreign_key: true
      t.references :task, null: true, foreign_key: { on_delete: :nullify }
      t.string :event_type, null: false
      t.string :message, null: false
      t.timestamps null: false
    end

    add_index :activity_events, :event_type
    add_index :activity_events, :created_at
    add_check_constraint :activity_events,
                         "event_type IN ('project_created', 'project_updated', 'task_created', 'task_updated', 'task_completed', 'task_deleted')",
                         name: "activity_events_type_check"
  end
end