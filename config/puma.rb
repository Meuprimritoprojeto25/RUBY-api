# frozen_string_literal: true

require "fileutils"

max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads max_threads_count, max_threads_count

port ENV.fetch("PORT", 3000)
environment ENV.fetch("RAILS_ENV", "development")

# A preview container starts without the ignored tmp/ tree. Puma writes its PID
# during boot, so ensure the configured parent directory exists before Puma
# opens the file. This also supports deployments that provide a custom PIDFILE.
pidfile_path = ENV.fetch("PIDFILE", "tmp/pids/server.pid")
FileUtils.mkdir_p(File.dirname(pidfile_path))
pidfile pidfile_path

plugin :tmp_restart
