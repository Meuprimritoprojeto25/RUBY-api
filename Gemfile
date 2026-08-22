source "https://rubygems.org"

ruby ">= 3.1.0"

# Pin the web stack instead of relying only on the lockfile. Railpack installs
# gems in a layer before the application source is copied; exact declarations
# prevent a stale compact-index response from resolving the former Sinatra 4 /
# Rack 3 stack that cannot be installed by its Bundler 2.3 runtime.
gem "sinatra", "3.2.0"
gem "puma", "~> 6.0"
# Keep the Rack 2 line explicit. It ships the `rackup` executable used by
# preview providers to boot config.ru applications, avoiding the separate
# Rack 3 companion gems and their incompatible compact-index metadata.
gem "rack", "2.2.10"
gem "rack-protection", "3.2.0"
gem "activerecord", "~> 7.1"
gem "sqlite3", "~> 1.7"
gem "bcrypt", "~> 3.1"