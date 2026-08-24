# frozen_string_literal: true

require "estate/jobs/engine"

module Estate
  module Jobs
    class InternalJobsController < Estate::Jobs::ApplicationController
      TOKEN = Engine.instance.config.estate_jobs.token ||
              ENV.fetch("ESTATE_JOBS_TOKEN", nil)

      before_action :authorize!

      def show
        render json: {
          app: Rails.application.class.module_parent_name.to_s,
          version: CONTRACT_VERSION,
          generated_at: Time.current.utc.iso8601,
          solid_queue: Queries.snapshot
        }
      end

      private

      def authorize!
        render json: { error: "unauthorized" }, status: :unauthorized unless
          Estate::Jobs.authorized?(request.headers["Authorization"].to_s, TOKEN)
      end
    end
  end
end
