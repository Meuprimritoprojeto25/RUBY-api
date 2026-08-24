require "fileutils"
require "json"
require "logger"
require "pathname"
require "date"
require "time"
require "active_record"
require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/date/calculations"

ROOT = Pathname.new(File.expand_path("..", __dir__)).freeze unless defined?(ROOT)

require_relative "../lib/database"
require_relative "../app/models/application_record"
require_relative "../app/models/project"
require_relative "../app/models/task"
require_relative "../db/seeds"

# Preparing here gives every executable entry point (Puma, rackup, and Rake)
# the same clean-database bootstrap behaviour.
Database.prepare!
DemoData.load! if ENV["DASHBOARDIA_DEMO_MODE"] == "true"