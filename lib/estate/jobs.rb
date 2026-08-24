# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/integer/time"
require_relative "estate/jobs/version"
require_relative "estate/jobs/engine"

module Estate
  module Jobs
    # Bumped on contract changes; reporters declare it, aggregators read it.
    CONTRACT_VERSION = 1

    # How many failed executions to include. The panel shows them all; the
    # payload stays bounded regardless of how bad a day the queue had.
    FAILURE_LIMIT = 10
    MAX_ARGUMENTS_LENGTH = 300

    # Constant-time by hashing both sides: the token is short, the digest is
    # fixed-length, and nobody learns anything from response timing.
    def self.authorized?(authorization_header, configured)
      return false if configured.blank?

      provided = authorization_header.to_s.delete_prefix("Bearer ")
      ActiveSupport::SecurityUtils.secure_compare(
        Digest::SHA256.hexdigest(provided), Digest::SHA256.hexdigest(configured)
      )
    end
  end
end
