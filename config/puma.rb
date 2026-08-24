threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", ENV.fetch("PUMA_THREADS", "5")))
threads threads_count, threads_count

port Integer(ENV.fetch("PORT", "9292"))
bind ENV.fetch("BIND", "0.0.0.0")

environment ENV.fetch("RACK_ENV", "development")