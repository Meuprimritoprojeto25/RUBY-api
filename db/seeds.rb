# frozen_string_literal: true

# Keep production data under the operator's control. The marketplace demo is
# loaded automatically only when the explicit opt-in flag is enabled.
Marketplace::DemoBootstrap.call if ENV["DASHBOARDIA_DEMO_MODE"] == "true"
