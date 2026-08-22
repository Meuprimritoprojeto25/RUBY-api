source "https://rubygems.org"

ruby ">= 3.1.0"

gem "puma", "~> 6.0"
# The application implements its small HTTP layer directly on Rack. Besides
# reducing boot dependencies, this avoids Sinatra/rack-protection metadata
# that the preview builder's stale compact index cannot install with Bundler
# 2.3. Rack 2 includes both Rack::Session::Cookie and the rackup executable.
gem "rack", "2.2.10"
gem "activerecord", "~> 7.1"
gem "sqlite3", "~> 1.7"
gem "bcrypt", "~> 3.1"