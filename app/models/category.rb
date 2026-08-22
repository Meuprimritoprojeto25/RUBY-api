# frozen_string_literal: true

class Category < ApplicationRecord
  has_many :listings, dependent: :restrict_with_error

  before_validation :normalize_slug

  validates :name, presence: true, length: { maximum: 60 }, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, length: { maximum: 70 },
                   format: { with: /\A[a-z0-9-]+\z/ }, uniqueness: { case_sensitive: false }

  private

  def normalize_slug
    self.slug = slug.to_s.strip.downcase
  end
end