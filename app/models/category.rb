# frozen_string_literal: true

class Category < ApplicationRecord
  has_many :products, dependent: :restrict_with_error

  before_validation :set_slug

  validates :name, presence: true, length: { maximum: 60 }, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: { case_sensitive: false },
                   format: { with: /\A[a-z0-9-]+\z/ }

  private

  def set_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
