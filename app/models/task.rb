class Task < ApplicationRecord
  STATES = %w[todo in_progress done].freeze
  PRIORITIES = %w[low medium high].freeze

  belongs_to :project, inverse_of: :tasks
  has_many :activity_events, dependent: :nullify, inverse_of: :task

  validates :project, presence: true
  validates :title, presence: true, length: { maximum: 180 }
  validates :description, exclusion: { in: [nil] }, length: { maximum: 5_000 }
  validates :state, inclusion: { in: STATES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :due_on, comparison: { greater_than_or_equal_to: Date.current }, allow_nil: true, on: :create

  scope :recent, -> { order(updated_at: :desc) }
  scope :open, -> { where.not(state: "done") }
  scope :due_soon, -> { open.where(due_on: Date.current..(Date.current + 7)).order(due_on: :asc, priority: :desc) }
  scope :overdue, -> { open.where.not(due_on: nil).where("due_on < ?", Date.current).order(due_on: :asc) }
end