# frozen_string_literal: true

# Abstract base class for all background jobs in this application.
#
# All jobs inherit from this class (instead of +ActiveJob::Base+ directly)
# so we can define shared retry/discard behaviour in one place.
#
# == Backend
#
# Jobs are processed by Solid Queue, which stores them in the PostgreSQL
# database. No external queue service (Redis, RabbitMQ) is required.
#
# == Shared behaviour configured here
#
# 1. **Deadlock retry** — if two jobs try to update the same rows and
#    PostgreSQL raises a deadlock error, the job is automatically retried
#    up to 3 times with a 5-second wait. This is a transient database
#    condition that resolves itself.
#
# 2. **Deserialization discard** — if a job references a record that was
#    deleted between enqueue and execution (e.g. a user deletes a document
#    before its processing job runs), Active Job raises a
#    +DeserializationError+. We discard (permanently skip) the job because
#    there's nothing left to process.
#
# @abstract Subclass this to create a new job. Do not enqueue this class directly.
#
# @see ProcessDocumentJob Processes a single document
# @see BatchProcessDocumentsJob Enqueues processing for multiple documents
class ApplicationJob < ActiveJob::Base
  # Retry on database deadlocks — these are transient and resolve when
  # the conflicting transaction completes. 5-second wait gives the other
  # transaction time to finish.
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  # Discard jobs whose referenced records no longer exist. This happens
  # when a user deletes a resource after the job was enqueued but before
  # it ran. Retrying would just fail again, so we skip it.
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.warn(
      "[#{job.class.name}] Discarding job due to deserialization error: #{error.message}"
    )
  end
end
