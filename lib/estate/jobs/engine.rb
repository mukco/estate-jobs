# frozen_string_literal: true

require "rails"
require "estate/jobs"

module Estate
  module Jobs
    # Mountable engine: draws the reporter endpoint and nothing else.
    #
    #   # config/routes.rb
    #   mount Estate::Jobs::Engine => "/internal/jobs"
    #
    # Auth is a shared bearer token: set ESTATE_JOBS_TOKEN on every app that
    # mounts the engine, and hand the same value to every aggregator. A wrong
    # or missing token answers 401; there is no anonymous mode — an endpoint
    # that reports queue internals should not exist unauthenticated even on
    # a private network.
    class Engine < ::Rails::Engine
      isolate_namespace Estate::Jobs
    end
  end
end
