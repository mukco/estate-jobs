# frozen_string_literal: true

require "net/http"
require_relative "queries"

module Estate
  module Jobs
    # The consumer half: fetch a sibling's report. Nothing raises — a dead or
    # unauthenticated reporter comes back as { ok: false, error: reason }, the
    # same shape every Ops service on the estate renders as words.
    module Client
      TIMEOUT = 5

      module_function

      def fetch(url, token:, timeout: TIMEOUT)
        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port,
                                   use_ssl: uri.scheme == "https",
                                   open_timeout: timeout, read_timeout: timeout) do |http|
          http.get(uri.request_uri, { "Authorization" => "Bearer #{token}",
                                      "Accept" => "application/json" })
        end
        return { ok: false, error: "HTTP #{response.code}" } unless response.is_a?(Net::HTTPSuccess)

        payload = JSON.parse(response.body, symbolize_names: true)
        { ok: true, payload: }
      rescue StandardError => e
        { ok: false, error: "#{e.class}: #{e.message}" }
      end
    end
  end
end
