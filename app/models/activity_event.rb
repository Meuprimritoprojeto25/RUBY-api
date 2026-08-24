class ActivityEvent < ApplicationRecord
  EVENT_TYPES = %w[
    project_created
    project_updated
    task_created
    task_updated
    task_completed
    task_deleted
  ].freeze

  belongs_to :project, inverse_of: :activity_events
  belongs_to :task, optional: true, inverse_of: :activity_events

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :message, presence: true, length: { maximum: 500 }

  scope :recent, -> { order(created_at: :desc, id: :desc) }
end