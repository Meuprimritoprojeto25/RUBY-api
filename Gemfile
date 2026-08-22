source "https://rubygems.org"

ruby ">= 3.1.0"

gem "puma", "~> 6.0"
# The application implements its HTTP layer directly on Rack. Keep it direct
# and exact so a fresh build has no route to resolve the former Sinatra /
# Rack Protection graph. Rack 2 includes Rack::Session::Cookie and rackup.
#
# The 2.2.11 revision intentionally changes the dependency artifact used by
# the preview build: it prevents reuse of the previously cached 2.2.10 layer
# that still contained the removed Rack Protection dependency graph.
gem "rack", "2.2.11", require: false
gem "activerecord", "~> 7.1"
gem "sqlite3", "~> 1.7"
gem "bcrypt", "~> 3.1"