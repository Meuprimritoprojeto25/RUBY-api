# frozen_string_literal: true

# Keeps the anonymous cart and signed-in account in a signed, HTTP-only cookie.
Rails.application.config.session_store :cookie_store,
                                       key: "_ruby_api_session",
                                       httponly: true,
                                       same_site: :lax,
                                       secure: Rails.env.production? && ENV["FORCE_SSL"] == "true"
