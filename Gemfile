source "https://rubygems.org"

ruby ">= 3.1.0"

gem "sinatra", "~> 4.0"
gem "puma", "~> 6.0"
# Rack 3 moved the `rackup` executable out of the rack gem. Some preview
# providers launch config.ru applications through `bundle exec rackup`, so it
# must be declared directly rather than relying on a transitive dependency.
gem "rackup", "~> 2.2"
gem "activerecord", "~> 7.1"
gem "sqlite3", "~> 1.7"
gem "bcrypt", "~> 3.1"
# rack-protection 4.1 requires Logger >= 1.6. Declaring it explicitly keeps
# that runtime dependency present in the checked-in bundle definition.
gem "logger", "~> 1.6"