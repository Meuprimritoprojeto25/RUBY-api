# frozen_string_literal: true

# Conventional application library root.
#
# Railpack's Rails build plan copies this directory into the image. Keeping a
# versioned Ruby source file here ensures that the directory is present in a
# clean checkout (Git does not retain empty directories).
module Marketplace
end