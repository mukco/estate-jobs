# frozen_string_literal: true

require "active_record"
require "estate/jobs/queries"

# Inline AR models over the real Solid Queue schema (loaded from the estate's
# own pg_dump — see support/solid_queue_schema.sql). Resolves exactly the way
# Queries.constantize does at runtime.
module SolidQueue
  class Process < ActiveRecord::Base
      self.table_name = "solid_queue_processes"
    end
  class Job < ActiveRecord::Base
      self.table_name = "solid_queue_jobs"
    end
  class ReadyExecution < ActiveRecord::Base
    self.table_name = "solid_queue_ready_executions"
    belongs_to :job, class_name: "SolidQueue::Job", optional: true
  end
  class ClaimedExecution < ActiveRecord::Base
    self.table_name = "solid_queue_claimed_executions"
    belongs_to :job, class_name: "SolidQueue::Job", optional: true
  end
  class FailedExecution < ActiveRecord::Base
    self.table_name = "solid_queue_failed_executions"
    belongs_to :job, class_name: "SolidQueue::Job"
  end
  class FinishedExecution < ActiveRecord::Base
    self.table_name = "solid_queue_finished_executions"
  end
  class RecurringTask < ActiveRecord::Base
      self.table_name = "solid_queue_recurring_tasks"
    end
end

ActiveRecord::Base.establish_connection(
  adapter: "postgresql", host: ENV.fetch("PGHOST", "127.0.0.1"),
  port: ENV.fetch("PGPORT", 5432).to_i,
  database: ENV.fetch("PGDATABASE", "estate_jobs_test"),
  username: ENV.fetch("PGUSER", "baseball"), password: ENV.fetch("PGPASSWORD", "baseball")
)

# Fresh CI services ship an empty cluster: make the database if it isn't there.
begin
  ActiveRecord::Base.connection.select_value("SELECT 1")
rescue ActiveRecord::NoDatabaseError
  require "pg"
  boot = PG.connect(
    host: ENV.fetch("PGHOST", "127.0.0.1"), port: ENV.fetch("PGPORT", 5432),
    user: ENV.fetch("PGUSER", "baseball"), password: ENV.fetch("PGPASSWORD", "baseball"),
    dbname: "postgres"
  )
  boot.exec("CREATE DATABASE #{ENV.fetch('PGDATABASE', 'estate_jobs_test')} OWNER #{ENV.fetch('PGUSER', 'baseball')}")
  boot.close
  ActiveRecord::Base.establish_connection(
    adapter: "postgresql", host: ENV.fetch("PGHOST", "127.0.0.1"),
    port: ENV.fetch("PGPORT", 5432).to_i,
    database: ENV.fetch("PGDATABASE", "estate_jobs_test"),
    username: ENV.fetch("PGUSER", "baseball"), password: ENV.fetch("PGPASSWORD", "baseball")
  )
end

SQL = File.read(File.join(__dir__, "solid_queue_schema.sql"))
AR = ActiveRecord::Base.connection

RSpec.configure do |config|
  config.before(:each, :solid_queue) do
    # Rebuild from scratch every time: deterministic beats clever, and one
    # example deliberately drops a table to prove sections fail independently.
    AR.execute("DROP SCHEMA public CASCADE")
    AR.execute("CREATE SCHEMA public")
    # The estate dump stamps every object OWNER TO family_hub; the role need
    # not exist here for the tables to work, but the statements do reference it.
    AR.execute("DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='family_hub') THEN CREATE ROLE family_hub NOLOGIN; END IF; END $$;")
    SQL.split(/;\s*\n/).map(&:strip)
       .reject { |stmt| stmt.empty? || stmt.start_with?("\\") }
       .each_with_index { |stmt, i| begin; AR.execute(stmt); rescue => e; warn "LOAD FAIL ##{i}: #{e.message[0,90]}"; raise; end }
    # pg_dump leaves the session search_path empty; pin it back so every
    # unqualified reference in the gem and specs resolves to public.
    AR.execute("SET search_path = public")
    warn "HOOK db=#{ActiveRecord::Base.connection_db_config.database} tables=#{AR.select_value("SELECT count(*) FROM pg_tables WHERE schemaname='public'")}"
  end

  def insert_job(id:, queue: "default", class_name: "TestJob", args: [])
    AR.execute(<<~SQL)
      INSERT INTO solid_queue_jobs (id, queue_name, class_name, arguments, priority,
        active_job_id, scheduled_at, finished_at, concurrency_key, created_at, updated_at)
      VALUES (#{id}, '#{queue}', '#{class_name}', '[#{args.map { |a| %("#{a}") }.join(",")}]', 0,
        NULL, NULL, NULL, NULL, NOW(), NOW())
    SQL
  end

  def insert_failed(job_id:, error_class: "RuntimeError", message: "boom")
    # 1.7 schema keeps a single combined error column.
    AR.execute(<<~SQL)
      INSERT INTO solid_queue_failed_executions (job_id, error, created_at)
      VALUES (#{job_id}, '#{error_class}: #{message}', NOW())
      ON CONFLICT (job_id) DO UPDATE SET error = excluded.error
    SQL
  end
end
