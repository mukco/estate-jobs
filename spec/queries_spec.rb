# frozen_string_literal: true

require "rails_helper"

RSpec.describe Estate::Jobs::Queries, :solid_queue do
  describe ".snapshot", :solid_queue do
    it "reports processes with heartbeat staleness" do
      AR.execute("INSERT INTO solid_queue_processes (kind, name, pid, last_heartbeat_at, created_at)
                  VALUES ('Worker', 'fresh', 100, NOW(), NOW())")
      AR.execute("INSERT INTO solid_queue_processes (kind, name, pid, last_heartbeat_at, created_at)
                  VALUES ('Worker', 'stale', 101, NOW() - interval '1 hour', NOW())")

      snap = described_class.snapshot
      expect(snap[:processes][:count]).to eq(2)
      expect(snap[:processes][:stale_count]).to eq(1)
    end

    it "counts queue depths across ready, claimed and failed" do
      insert_job(id: 1, queue: "default")
      insert_job(id: 2, queue: "default")
      insert_job(id: 3, queue: "live")
      AR.execute("INSERT INTO solid_queue_ready_executions (job_id, queue_name, priority, created_at)
                  VALUES (1,'default',0,NOW()), (2,'default',0,NOW()), (3,'live',0,NOW())")
      insert_failed(job_id: 3)

      insert_failed(job_id: 3)

      queues = described_class.queues
      expect(queues["default"]).to include(ready: 2)
      expect(queues["default"][:failed]).to eq(0) # failed rows live on the job's queue via join below
      expect(queues["live"][:ready]).to eq(1)
    end

    it "lists recurring tasks" do
      AR.execute("INSERT INTO solid_queue_recurring_tasks (key, class_name, schedule, static, created_at, updated_at)
                  VALUES ('weekend_search','Home::SearchEventsJob','0 9 * * 4,6',true,NOW(),NOW())")

      rec = described_class.recurring
      expect(rec.size).to eq(1)
      expect(rec.first).to include(key: "weekend_search", class_name: "Home::SearchEventsJob")
      expect(rec.first[:schedule]).to eq('0 9 * * 4,6')
    end

    it "reports failures with class, message and bounded arguments" do
      insert_job(id: 10, class_name: "PushDeliveryJob", args: %w[one two])
      insert_failed(job_id: 10, error_class: "Net::ReadTimeout", message: "too slow")

      failures = described_class.failures(limit: 5)
      expect(failures.size).to eq(1)
      expect(failures.first).to include(class_name: "PushDeliveryJob", error_class: "Net::ReadTimeout",
                                        error_message: "too slow")
      expect(failures.first[:arguments]).to eq(["one", "two"])
    end

    it "keeps every section alive when a table is missing" do
      AR.execute("DROP TABLE solid_queue_recurring_tasks")
      snap = described_class.snapshot
      expect(snap[:recurring]).to include(:unavailable)
      expect(snap[:queues]).to be_a(Hash)
      expect(snap[:recurring][:unavailable]).to match(/UndefinedTable|PG::/)
    end
  end
end
