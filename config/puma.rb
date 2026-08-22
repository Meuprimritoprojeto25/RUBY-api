# frozen_string_literal: true

# Puma discovers this file automatically when started with `bundle exec puma`.
# Binding to all interfaces makes the application usable in temporary previews
# while PORT remains configurable by the hosting environment.
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', '9292')}"
environment ENV.fetch("RACK_ENV", ENV.fetch("APP_ENV", "development"))
threads_count = ENV.fetch("PUMA_THREADS", "5").to_i
threads threads_count, threads_count