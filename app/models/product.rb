# frozen_string_literal: true

class Product < ApplicationRecord
  belongs_to :seller, class_name: "User", inverse_of: :products
  belongs_to :category, inverse_of: :products
  has_many :order_items, dependent: :restrict_with_error

  scope :active, -> { where(status: "active") }
  scope :featured, -> { active.where(featured: true) }

  validates :title, presence: true, length: { maximum: 120 }
  validates :description, presence: true, length: { maximum: 2_000 }
  validates :price, numericality: { greater_than: 0 }
  validates :original_price, numericality: { greater_than: 0 }, allow_nil: true
  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: %w[active paused sold_out] }
  validates :image_url, length: { maximum: 500 }, allow_blank: true

  def discount_percentage
    return 0 unless original_price.present? && original_price > price

    (((original_price - price) / original_price) * 100).round
  end
end
