class Project < ApplicationRecord
  STATUSES = %w[active paused completed].freeze

  has_many :tasks, dependent: :destroy, inverse_of: :project

  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { case_sensitive: false }
  validates :code, presence: true, length: { maximum: 24 },
                   format: { with: /\A[a-z0-9-]+\z/, message: "must use lowercase letters, numbers, and hyphens" },
                   uniqueness: { case_sensitive: false }
  validates :description, exclusion: { in: [nil] }, length: { maximum: 2_000 }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(updated_at: :desc) }
end