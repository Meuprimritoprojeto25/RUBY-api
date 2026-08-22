# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_many :products, foreign_key: :seller_id, dependent: :restrict_with_error, inverse_of: :seller
  has_many :orders, foreign_key: :buyer_id, dependent: :restrict_with_error, inverse_of: :buyer

  before_validation :normalize_identity

  validates :username, presence: true, length: { in: 3..40 }, uniqueness: { case_sensitive: false }
  validates :email, presence: true, length: { maximum: 120 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :role, inclusion: { in: %w[buyer seller admin] }

  private

  def normalize_identity
    self.email = email.to_s.strip.downcase
    self.username = username.to_s.strip
  end
end
