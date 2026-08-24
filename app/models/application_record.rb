class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Keep audit columns valid even when records are created outside the HTTP
  # layer (seeds, console scripts, or future background jobs).
  before_validation :set_created_audit_timestamp, on: :create
  before_update :set_updated_audit_timestamp

  private

  def set_created_audit_timestamp
    now = Time.now.utc
    self.created_at ||= now
    self.updated_at ||= now
  end

  def set_updated_audit_timestamp
    self.updated_at = Time.now.utc
  end
end