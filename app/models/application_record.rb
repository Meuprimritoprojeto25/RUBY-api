# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Active Record timestamps are deliberately set here rather than by callers,
  # so imports, seeds and web requests all receive the same audit behavior.
  before_create :set_audit_timestamps
  before_update :set_updated_timestamp

  private

  def set_audit_timestamps
    now = Time.now.utc
    self.created_at ||= now
    self.updated_at ||= now
  end

  def set_updated_timestamp
    self.updated_at = Time.now.utc
  end
end