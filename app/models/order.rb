# frozen_string_literal: true

class Order < ApplicationRecord
  STATUSES = %w[pending paid shipped cancelled].freeze

  belongs_to :buyer, class_name: "User"
  has_many :order_items, dependent: :restrict_with_error

  validates :buyer, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :total_cents, numericality: { only_integer: true, greater_than: 0 }
end