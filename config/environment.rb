# frozen_string_literal: true

require "bundler/setup"
require "active_record"
require "fileutils"
require "logger"

APP_ROOT = File.expand_path("..", __dir__) unless defined?(APP_ROOT)
ENV["RACK_ENV"] ||= ENV.fetch("APP_ENV", "development")

default_database = File.join(APP_ROOT, "db", "marketplace.sqlite3")
FileUtils.mkdir_p(File.dirname(default_database))
database_url = ENV.fetch("DATABASE_URL", "sqlite3:#{default_database}")

ActiveRecord::Base.establish_connection(database_url)
ActiveRecord::Base.logger = Logger.new($stdout) if ENV["SQL_LOG"] == "true"
ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")

if ENV.fetch("AUTO_MIGRATE", "true") == "true"
  migration_context = ActiveRecord::MigrationContext.new(File.join(APP_ROOT, "db", "migrate"))
  migration_context.up
end

require_relative "../app/models/application_record"
require_relative "../app/models/user"
require_relative "../app/models/category"
require_relative "../app/models/listing"
require_relative "../app/models/order"
require_relative "../app/models/order_item"
require_relative "../db/demo_data"

DemoData.seed! if ENV["DASHBOARDIA_DEMO_MODE"] == "true"

require_relative "../app/marketplace_app"