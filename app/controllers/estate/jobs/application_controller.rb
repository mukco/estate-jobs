# frozen_string_literal: true

module Estate
  module Jobs
    # Deliberately ActionController::API rather than ::Base: no cookies, no
    # sessions, no CSRF — a bearer header is the whole contract, and this way
    # the engine behaves identically inside API-only and full-stack hosts.
    class ApplicationController < ActionController::API
    end
  end
end
