# frozen_string_literal: true

require_relative "app"

use Rack::Session::Cookie,
    key: "mercado_viva.session",
    path: "/",
    same_site: :lax,
    secret: ENV.fetch("SESSION_SECRET", "mercado-viva-development-session-secret-change-me-please-replace-this-value-before-production")

run MarketplaceApp