---
name: rails-job
description: "Write Sidekiq background jobs following project conventions: ApplicationJob inheritance, queue assignment, exponential retry strategies, external service calls, Sidekiq logger for errors, and sidekiq-cron for scheduled jobs. Use this skill whenever creating background jobs, async tasks, scheduled jobs, or working in app/jobs/. Triggers on: 'create job', 'background job', 'sidekiq', 'async task', 'scheduled job', 'cron job', 'worker', 'queue', or any work in app/jobs/."
---

# Rails Background Job Patterns

This project uses Sidekiq 7.2 for background job processing and sidekiq-cron for scheduled recurring tasks. Jobs handle external service calls, bulk operations, and any long-running work that shouldn't block API responses.

## Job Location

```
app/jobs/
  application_job.rb         # Base class
  create_access_for_users_job.rb
  sync_employees_job.rb
```

## Job Skeleton

```ruby
# frozen_string_literal: true

class ProcessWidgetsJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 2

  def perform(org_uid)
    widgets = WidgetRepository.fetch_widgets(org_uid)
    widgets.each do |widget|
      result = WidgetService::Process.new(widget).call
      next if result.success

      Sidekiq.logger.error("Failed to process widget #{widget.uid}: #{result.errors}")
    end
  end
end
```

## Key Conventions

### Queue Assignment

Every job declares its queue. The default queue handles most work:

```ruby
queue_as :default
```

For priority-sensitive jobs, use named queues:

```ruby
queue_as :critical
queue_as :bulk_operations
queue_as :notifications
```

### Retry Strategy

Use `retry_on` with exponential backoff for transient failures:

```ruby
retry_on StandardError, wait: :exponentially_longer, attempts: 2
```

For specific error types:

```ruby
retry_on Net::OpenTimeout, wait: 5.seconds, attempts: 3
retry_on ActiveRecord::RecordNotFound, wait: :exponentially_longer, attempts: 2
```

For manual retry control (when you need custom logic):

```ruby
def perform(org_uid)
  result = ExternalService::HttpRequest.new(url, 'action', resource_url, params, token:).call

  return true if result['success']

  Sidekiq.logger.error(result['errors'][:base])
  retry_job if executions <= 3
end
```

### External Service Calls in Jobs

Jobs are the right place for external HTTP calls. Use the project's `ExternalService::HttpRequest` wrapper:

```ruby
def perform(org_uid)
  url = ENV.fetch('EXTERNAL_SERVICE_URL', nil)
  resource_url = '/api/endpoint'
  token = ENV.fetch('EXTERNAL_SERVICE_TOKEN')
  params = { org_uid: org_uid }

  response = ExternalService::HttpRequest.new(url, 'get', resource_url, params, token:).call

  return process_response(response) if response['success']

  Sidekiq.logger.error("External call failed: #{response['errors']}")
  retry_job if executions <= 3
end
```

### Error Logging

Always log errors to Sidekiq's logger, not Rails logger:

```ruby
Sidekiq.logger.error("Job failed for org #{org_uid}: #{error.message}")
Sidekiq.logger.warn("Retrying job, attempt #{executions}")
Sidekiq.logger.info("Job completed for org #{org_uid}")
```

### Job with Transaction

When a job modifies multiple records, wrap in a transaction:

```ruby
def perform(org_uid, widget_uids)
  ActiveRecord::Base.transaction do
    widget_uids.each do |uid|
      widget = WidgetRepository.find_by_column(:uid, uid)
      next unless widget

      widget.update!(status: :processed)
    end
  end
rescue ActiveRecord::RecordInvalid => e
  Sidekiq.logger.error("Transaction failed: #{e.message}")
end
```

## Scheduled Jobs (sidekiq-cron)

For recurring tasks, configure in `config/initializers/sidekiq_cron.rb`:

```ruby
# config/initializers/sidekiq_cron.rb
Sidekiq::Cron::Job.load_from_hash(
  'sync_employees' => {
    'class' => 'SyncEmployeesJob',
    'cron' => '0 2 * * *',       # Daily at 2 AM
    'queue' => 'default',
    'description' => 'Sync employee data from external service'
  },
  'cleanup_expired' => {
    'class' => 'CleanupExpiredJob',
    'cron' => '0 */6 * * *',     # Every 6 hours
    'queue' => 'default'
  }
)
```

## Enqueueing Jobs

From controllers or services:

```ruby
# Enqueue immediately
ProcessWidgetsJob.perform_later(org_uid)

# Enqueue with delay
ProcessWidgetsJob.set(wait: 5.minutes).perform_later(org_uid)

# Enqueue at specific time
ProcessWidgetsJob.set(wait_until: Date.tomorrow.noon).perform_later(org_uid)
```

## Job Arguments

Keep job arguments simple and serializable. Pass IDs/UIDs, not full objects:

```ruby
# Good — passes a UID string
ProcessWidgetsJob.perform_later(organisation.uid)

# Bad — passes an ActiveRecord object
ProcessWidgetsJob.perform_later(organisation)
```

## Monitoring

Sidekiq Web UI is mounted at `/sidekiq` in routes. It provides job monitoring, retry management, and queue inspection.

## Checklist Before Writing a Job

1. Does it inherit from `ApplicationJob`?
2. Is `queue_as` specified?
3. Is there a `retry_on` strategy?
4. Are errors logged with `Sidekiq.logger`?
5. Are arguments simple serializable values (strings, integers, UIDs)?
6. Are external calls using `ExternalService::HttpRequest`?
7. Is `# frozen_string_literal: true` at the top?
