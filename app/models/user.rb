# frozen_string_literal: true

require "bcrypt"
require "uri"

class User < ApplicationRecord
  has_secure_password

  has_many :listings, foreign_key: :seller_id, dependent: :restrict_with_error
  has_many :orders, foreign_key: :buyer_id, dependent: :restrict_with_error

  before_validation :normalize_identity

  validates :username, presence: true, length: { in: 3..30 },
                       format: { with: /\A[a-z0-9._-]+\z/, message: "use letras minúsculas, números, ponto, hífen ou _" },
                       uniqueness: { case_sensitive: false }
  validates :email, presence: true, length: { maximum: 120 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 8 }, allow_nil: true

  private

  def normalize_identity
    self.username = username.to_s.strip.downcase
    self.email = email.to_s.strip.downcase
  end
end