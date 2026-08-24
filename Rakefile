require "rake"
require_relative "config/environment"

namespace :db do
  desc "Create the SQLite database and apply all pending migrations"
  task :migrate do
    Database.prepare!
  end

  desc "Load the idempotent demonstration data"
  task :seed do
    Database.prepare!
    DemoData.load!
  end

  desc "Remove all application records and reload demonstration data"
  task :reset do
    Database.prepare!
    Task.delete_all
    Project.delete_all
    DemoData.load!
  end
end