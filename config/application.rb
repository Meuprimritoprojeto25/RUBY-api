# frozen_string_literal: true

require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module RubyApi
  class Application < Rails::Application
    config.load_defaults 7.1
    config.time_zone = "America/Sao_Paulo"
    config.i18n.default_locale = :"pt-BR"
    config.generators.system_tests = nil
  end
end
