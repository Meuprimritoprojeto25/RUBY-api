# frozen_string_literal: true

class Listing < ApplicationRecord
  CONDITIONS = %w[new used refurbished].freeze

  belongs_to :seller, class_name: "User"
  belongs_to :category
  has_many :order_items, dependent: :restrict_with_error

  before_validation :normalize_fields

  validates :title, presence: true, length: { maximum: 120 }
  validates :description, presence: true, length: { maximum: 2_000 }
  validates :seller, :category, presence: true
  validates :price_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :condition, inclusion: { in: CONDITIONS }
  validates :location, presence: true, length: { maximum: 100 }
  validates :image_url, length: { maximum: 500 }, allow_blank: true

  scope :available, -> { where("stock > 0") }
  scope :featured_first, -> { order(featured: :desc, created_at: :desc) }

  def available?
    stock.positive?
  end

  def price
    price_cents / 100.0
  end

  private

  def normalize_fields
    self.title = title.to_s.strip
    self.description = description.to_s.strip
    self.location = location.to_s.strip
    self.image_url = image_url.to_s.strip
  end
end