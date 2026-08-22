source "https://rubygems.org"

ruby ">= 3.1.0"

gem "puma", "~> 6.0"
# The application implements its small HTTP layer directly on Rack. Besides
# reducing boot dependencies, this avoids Sinatra/rack-protection metadata
# that the preview builder's stale compact index cannot install with Bundler
# 2.3. Keep Rack as a direct, exact dependency: the preview build copies this
# manifest before the application source and must never resolve a former
# Sinatra/Rack Protection dependency graph from a cached layer. Rack 2
# includes Rack::Session::Cookie and the rackup executable. It is required
# explicitly by config.ru after the application environment has loaded.
gem "rack", "2.2.10", require: false
gem "activerecord", "~> 7.1"
gem "sqlite3", "~> 1.7"
gem "bcrypt", "~> 3.1"