# frozen_string_literal: true

class Order < ApplicationRecord
  belongs_to :buyer, class_name: "User", inverse_of: :orders
  has_many :order_items, dependent: :destroy, inverse_of: :order

  validates :number, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[pending paid cancelled] }
  validates :subtotal, :total, numericality: { greater_than_or_equal_to: 0 }
end
