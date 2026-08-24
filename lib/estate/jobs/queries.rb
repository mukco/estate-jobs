# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/integer/time"

module Estate
  module Jobs
    # Reads this app's Solid Queue state. Read-only AR over the solid_queue_*
    # tables — same connection, no second database, no configuration.
    #
    # Every query is individually rescued: an app without Solid Queue (or a
    # cluster mid-migration) reports { unavailable: reason } for that section
    # rather than failing the whole payload. The aggregator renders words, not
    # stack traces.
    module Queries
      STALE_HEARTBEAT = 5.minutes

      module_function

      def snapshot
        { processes:, queues:, recurring:, failures:, totals: }
      rescue StandardError => e
        { unavailable: "#{e.class}: #{e.message}" }
      end

      def processes
        rows = process_class.order(:kind, :name).map do |p|
          {
            kind: p.kind, name: p.name, pid: p.pid,
            last_heartbeat_at: p.last_heartbeat_at&.utc&.iso8601,
            stale: p.last_heartbeat_at.nil? || p.last_heartbeat_at < STALE_HEARTBEAT.ago
          }
        end
        { count: rows.size, stale_count: rows.count { |r| r[:stale] }, rows: }
      rescue StandardError => e
        { unavailable: "#{e.class}: #{e.message}" }
      end

      def queues
        # Pre-1.7 executions carry queue_name; newer ones reach it through
        # their job. Either way the answer is grouped by real queue name.
        count_by_queue = lambda do |execution_class|
          if execution_class.column_names.include?("queue_name")
            execution_class.group(:queue_name).count
          else
            execution_class.joins(:job).group("solid_queue_jobs.queue_name").count
          end
        end

        counts = Hash.new { |h, k| h[k] = { ready: 0, claimed: 0 } }
        count_by_queue.call(ready_class).each { |q, n| counts[q][:ready] = n }
        count_by_queue.call(claimed_class).each { |q, n| counts[q][:claimed] = n }
        failed = count_by_queue.call(failed_class.all)
        counts.keys.union(failed.keys).sort.to_h { |q| [q, counts[q].merge(failed: failed[q] || 0)] }
      rescue StandardError => e
        { unavailable: "#{e.class}: #{e.message}" }
      end

      def recurring
        task_class.order(:key).map do |t|
          {
            key: t.key, class_name: (t.class_name if t.respond_to?(:class_name)),
            schedule: t.schedule,
            last_enqueued_at: t.respond_to?(:last_enqueued_at) ? t.last_enqueued_at&.utc&.iso8601 : nil
          }
        end
      rescue StandardError => e
        { unavailable: "#{e.class}: #{e.message}" }
      end

      def failures(limit: FAILURE_LIMIT)
        cols = failed_class.column_names
        legacy = cols.include?("error_class") # pre-1.7 schema kept them apart
        failed_class.includes(:job).order(created_at: :desc).limit(limit).map do |f|
          job = f.job
          error_class, error_message =
            if legacy
              [f.error_class, f.error_message]
            else
              combined = f.error.to_s
              [combined.split(": ", 2)[0], combined.split(": ", 2)[1]]
            end
          {
            queue: job.queue_name, class_name: job.class_name,
            error_class:, error_message: truncate(error_message),
            arguments: filter_arguments(job.arguments),
            failed_at: f.created_at&.utc&.iso8601
          }
        end
      rescue StandardError => e
        { unavailable: "#{e.class}: #{e.message}" }
      end

      def totals
        {
          ready: ready_class.count, claimed: claimed_class.count,
          failed: failed_class.count,
          finished_last_24h: begin
            finished_class.where(finished_at: 24.hours.ago..).count
          rescue StandardError
            nil
          end
        }
      rescue StandardError => e
        { unavailable: "#{e.class}: #{e.message}" }
      end

      # Solid Queue stores arguments as JSON; hand back the parsed structure
      # when it parses, so aggregators get real arrays and hashes. Bounded.
      def filter_arguments(args)
        s = args.is_a?(String) ? args : Array(args).to_json
        parsed = JSON.parse(s)
        parsed = parsed[0, MAX_ARGUMENTS_LENGTH] + ["..."] if parsed.is_a?(Array) && parsed.size > MAX_ARGUMENTS_LENGTH
        parsed
      rescue JSON::ParserError, TypeError
        truncate(s)
      end

      def truncate(s, max = 500)
        s.to_s[0, max]
      end

      # Resolved lazily so the gem works against any Solid Queue version that
      # ships these models (1.0+), and so a missing table raises inside the
      # section that touched it instead of at load time.
      {
        process_class: "SolidQueue::Process",
        ready_class: "SolidQueue::ReadyExecution",
        claimed_class: "SolidQueue::ClaimedExecution",
        failed_class: "SolidQueue::FailedExecution",
        finished_class: "SolidQueue::FinishedExecution",
        task_class: "SolidQueue::RecurringTask"
      }.each do |name, constant|
        define_method(name) { constant.constantize }
      end
    end
  end
end
