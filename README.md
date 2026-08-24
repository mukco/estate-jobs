# estate-jobs

One JSON reporter per Rails app: mount it, set a token, and the estate panel
can see your Solid Queue.

```ruby
# Gemfile
gem "estate-jobs", github: "mukco/estate-jobs", tag: "v0.1.0"
```

```ruby
# config/routes.rb
mount Estate::Jobs::Engine => "/internal/jobs"
```

```
ESTATE_JOBS_TOKEN=<shared secret, same value on every app and every aggregator>
```

## What it reports

`GET /internal/jobs` (Bearer token required) →

```json
{
  "app": "Baseball",
  "version": 1,
  "generated_at": "2026-08-24T09:00:00Z",
  "solid_queue": {
    "processes":  { "count": 4, "stale_count": 0, "rows": [ ... ] },
    "queues":     { "default": { "ready": 2, "claimed": 1, "failed": 0 } },
    "recurring":  [ { "key": "scheduled_live_refresh", "schedule": "every 30 seconds", ... } ],
    "failures":   [ { "class_name": "...", "error_class": "...", "failed_at": "...", ... } ],
    "totals":     { "ready": 3, "claimed": 1, "failed": 4, "finished_last_24h": 812 }
  }
}
```

Every section is individually rescued: an app without Solid Queue reports
`{ "unavailable": reason }` there instead of failing the payload.

## The client

```ruby
Estate::Jobs::Client.fetch("https://baseball.edwardsfamily.app/internal/jobs", token: token)
# => { ok: true,  payload: {...} }
# => { ok: false, error: "HTTP 401" }
```

Nothing raises. Render `error` as words.

## Versioning

`version` in the payload is the contract. Add keys freely within a version;
rename or remove means bumping.
