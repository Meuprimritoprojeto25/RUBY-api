# frozen_string_literal: true

# A preview deployment starts from an empty workspace.  Preparing SQLite here
# keeps the web entrypoint useful on its first request while `bin/setup` remains
# available for conventional deployments.
require "fileutils"

module Marketplace
  class DatabaseBootstrap
    def self.prepare!
      configuration = ActiveRecord::Base.connection_db_config.configuration_hash
      database = configuration[:database].to_s

      # SQLite creates its file on connect, but not its parent directory.
      FileUtils.mkdir_p(File.dirname(database)) if configuration[:adapter] == "sqlite3" && database.present?

      # SchemaMigration and InternalMetadata have changed their constructor
      # dependency from a connection to a connection pool between supported
      # Active Record releases. Let MigrationContext create those internal
      # collaborators so it uses the API that matches the installed Rails
      # version. Establishing the connection here also happens only after the
      # SQLite parent directory has been created.
      ActiveRecord::Base.connection
      ActiveRecord::MigrationContext.new([Rails.root.join("db/migrate")]).migrate
    end
  end
end

Rails.application.config.after_initialize do
  Marketplace::DatabaseBootstrap.prepare!
  Marketplace::DemoBootstrap.call if ENV["DASHBOARDIA_DEMO_MODE"] == "true"
end
