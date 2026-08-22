# frozen_string_literal: true

class OrderItem < ApplicationRecord
  belongs_to :order, inverse_of: :order_items
  belongs_to :product, inverse_of: :order_items

  validates :title, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, numericality: { greater_than: 0 }
end
