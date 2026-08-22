# frozen_string_literal: true

require "rake"
require "sequel"
require_relative "app"

namespace :db do
  desc "Apply database migrations"
  task :migrate do
    Sequel::Migrator.run(MercadoPulseApp::DB, File.join(MercadoPulseApp.root, "db", "migrate"))
    puts "Database migrations applied."
  end

  desc "Load idempotent marketplace demonstration data"
  task :seed do
    DemoSeeder.load(MercadoPulseApp::DB)
    puts "Demonstration catalog loaded."
  end

  desc "Remove the local SQLite database"
  task :reset do
    database_file = File.join(MercadoPulseApp.root, "db", "mercado_pulse.sqlite3")
    File.delete(database_file) if File.exist?(database_file)
    puts "Local database removed. It will be recreated on next start."
  end
end