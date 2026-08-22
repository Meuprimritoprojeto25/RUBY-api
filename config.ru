# frozen_string_literal: true

require_relative "config/environment"
require "rack/session/cookie"
require "rack/static"

use Rack::Static, urls: ["/styles.css"], root: File.join(APP_ROOT, "public")
use Rack::Session::Cookie,
    key: "vitrine_livre.session",
    secret: MarketplaceApp::SESSION_COOKIE_SECRET,
    same_site: :lax

run MarketplaceApp.new