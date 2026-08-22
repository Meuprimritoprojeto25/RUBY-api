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

# Rails 7.1 declares these as runtime dependencies of Active Support. The
# preview's Bundler 2.3 uses a compact-index response that omits them from its
# initial metadata, then rejects an otherwise valid lockfile after downloading
# the gem. Keeping the real runtime requirements explicit makes installation
# deterministic without changing the application stack.
gem "benchmark", "0.4.1", require: false
gem "logger", "1.6.0", require: false
gem "securerandom", "0.4.1", require: false