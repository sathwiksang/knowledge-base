# frozen_string_literal: true

# Enqueues {ProcessDocumentJob} for multiple documents in a knowledge base
# in a single operation.
#
# This is an **orchestrator job** — it does not process documents itself.
# It finds documents matching the given status filter, then enqueues one
# {ProcessDocumentJob} per document. This fan-out pattern lets individual
# documents retry independently if processing fails.
#
# == When it gets enqueued
#
# - **From the batch reprocess endpoint** —
#   {Api::V1::DocumentsController#batch_reprocess} enqueues this job when
#   a user wants to reprocess all pending/failed documents at once.
# - **From the Rails console** — ops can call {.process_all_pending} or
#   {.retry_failed} to recover from bulk failures (e.g. after an Ollama
#   outage).
#
# == Queue
#
# Runs on the +:default+ queue (Solid Queue, backed by PostgreSQL).
#
# == Expected duration
#
# The job itself is fast (seconds) because it only enqueues other jobs.
# It does NOT wait for the child {ProcessDocumentJob}s to complete.
# The actual document processing happens asynchronously.
#
# For a KB with 100 documents, this job takes ~1–5 seconds to iterate
# and enqueue all child jobs.
#
# == Retry behaviour
#
# | Error               | Attempts | Wait   | Reason                                 |
# |---------------------|----------|--------|----------------------------------------|
# | StandardError       | 3        | 1 min  | Catch-all for unexpected failures      |
# | RecordNotFound      | —        | Discard| KB was deleted after job was enqueued   |
#
# Individual document enqueue failures are caught and logged (they do
# NOT cause the entire batch job to fail). The job continues with the
# remaining documents.
#
# == Workflow
#
#   ┌──────────────────────────┐
#   │  BatchProcessDocumentsJob │
#   │       .perform            │
#   └────────────┬─────────────┘
#                │
#                ▼
#   ┌──────────────────────────┐
#   │ Load KnowledgeBase       │
#   │ (discard if not found)   │
#   └────────────┬─────────────┘
#                │
#                ▼
#   ┌──────────────────────────┐
#   │ Query documents matching │
#   │ status filter & limit    │
#   │ (ordered by created_at)  │
#   └────────────┬─────────────┘
#                │
#                ▼
#   ┌──────────────────────────┐
#   │   For each document:     │
#   │                          │
#   │   Should process?        │
#   │   ├── yes → enqueue      │──→  ProcessDocumentJob.perform_later
#   │   │         child job    │
#   │   └── no  → skip         │
#   │                          │
#   │   (errors are logged     │
#   │    and collected, not    │
#   │    re-raised)            │
#   └────────────┬─────────────┘
#                │
#                ▼
#   ┌──────────────────────────┐
#   │ Return BatchResult with  │
#   │ queued/skipped/error     │
#   │ counts                   │
#   └──────────────────────────┘
#
# == Database side effects
#
# - Documents with status "failed" are reset to "pending" when +force+
#   is true (so {ProcessDocumentJob} will pick them up).
# - One {ProcessDocumentJob} is enqueued in Solid Queue per document.
# - No chunks or embeddings are created/deleted by this job — that
#   happens in the child {ProcessDocumentJob}s.
#
# @example Enqueue from the controller (reprocess pending + failed)
#   BatchProcessDocumentsJob.perform_later(knowledge_base.id, statuses: ["pending", "failed"])
#
# @example Force-reprocess ALL documents (including already-indexed ones)
#   BatchProcessDocumentsJob.perform_later(kb.id, statuses: Document::STATUSES, force: true)
#
# @example Limit to 10 documents (e.g. for testing)
#   BatchProcessDocumentsJob.perform_later(kb.id, limit: 10)
#
# @example Retry all failed documents across every knowledge base
#   BatchProcessDocumentsJob.retry_failed
#
# @example Process all pending documents across every knowledge base
#   BatchProcessDocumentsJob.process_all_pending
#
# @example Monitor batch progress via Rails console
#   # Count remaining pending documents:
#   kb.documents.pending.count
#
#   # Count how many child jobs are still in the queue:
#   SolidQueue::Job.where(class_name: "ProcessDocumentJob").count
#
# @see ProcessDocumentJob The child job that does the actual processing
# @see Api::V1::DocumentsController#batch_reprocess API endpoint
# @see DocumentProcessorService The service behind each child job
class BatchProcessDocumentsJob < ApplicationJob
  queue_as :default

  # Catch-all retry for unexpected errors (e.g. transient DB issues).
  # Waits 1 minute between attempts to let transient issues resolve.
  retry_on StandardError, wait: 1.minute, attempts: 3

  # If the knowledge base was deleted after this job was enqueued,
  # there's nothing to process — discard permanently.
  discard_on ActiveRecord::RecordNotFound

  # Encapsulates the outcome of a batch enqueue operation.
  #
  # @!attribute [rw] knowledge_base_id
  #   @return [Integer] the KB that was processed
  # @!attribute [rw] total_documents
  #   @return [Integer] total documents matching the status filter
  # @!attribute [rw] queued_count
  #   @return [Integer] documents successfully enqueued for processing
  # @!attribute [rw] skipped_count
  #   @return [Integer] documents skipped (already processing/indexed)
  # @!attribute [rw] errors
  #   @return [Array<Hash>] enqueue failures, each with +:document_id+
  #     and +:error+ keys
  BatchResult = Struct.new(:knowledge_base_id, :total_documents, :queued_count, :skipped_count, :errors, keyword_init: true)

  # Enqueue {ProcessDocumentJob} for each qualifying document in a
  # knowledge base.
  #
  # @param knowledge_base_id [Integer] the knowledge base to process
  # @param options [Hash] processing options
  # @option options [Array<String>] :statuses (["pending", "failed"])
  #   which document statuses to include. Valid values: "pending",
  #   "processing", "indexed", "failed".
  # @option options [Boolean] :force (false) if +true+, enqueue even
  #   if a document is already indexed or processing. Also resets
  #   "failed" documents back to "pending".
  # @option options [Integer] :limit (nil) max number of documents to
  #   process. Useful for testing or gradual rollouts. +nil+ means no
  #   limit (process all matching documents).
  # @return [BatchResult] summary of what was enqueued, skipped, or errored
  def perform(knowledge_base_id, options = {})
    @options = options.symbolize_keys
    @statuses = @options[:statuses] || %w[pending failed]
    @force = @options[:force] || false
    @limit = @options[:limit]
    @errors = []

    knowledge_base = KnowledgeBase.find(knowledge_base_id)

    documents = fetch_documents(knowledge_base)
    total_count = documents.count

    Rails.logger.info(
      "[BatchProcessDocumentsJob] Processing #{total_count} documents for KB #{knowledge_base_id}"
    )

    queued_count = 0
    skipped_count = 0

    # Iterate in batches (find_each uses batches of 1000) to avoid
    # loading all documents into memory at once
    documents.find_each do |document|
      if should_process?(document)
        enqueue_document(document)
        queued_count += 1
      else
        skipped_count += 1
      end
    rescue StandardError => e
      # Collect errors but don't abort — one bad document shouldn't
      # prevent the rest from being enqueued
      @errors << { document_id: document.id, error: e.message }
      Rails.logger.error(
        "[BatchProcessDocumentsJob] Failed to enqueue document #{document.id}: #{e.message}"
      )
    end

    result = BatchResult.new(
      knowledge_base_id: knowledge_base_id,
      total_documents: total_count,
      queued_count: queued_count,
      skipped_count: skipped_count,
      errors: @errors
    )

    Rails.logger.info(
      "[BatchProcessDocumentsJob] Completed: #{queued_count} queued, #{skipped_count} skipped, #{@errors.count} errors"
    )

    result
  end

  # Enqueue batch processing for ALL knowledge bases with pending documents.
  #
  # Useful as a recovery command after an outage — run from the Rails
  # console to pick up all unprocessed documents across the system.
  #
  # @param options [Hash] forwarded to {#perform} (e.g. +force: true+)
  # @return [void]
  #
  # @example From Rails console
  #   BatchProcessDocumentsJob.process_all_pending
  def self.process_all_pending(options = {})
    KnowledgeBase.find_each do |kb|
      perform_later(kb.id, options)
    end
  end

  # Enqueue batch processing targeting only failed documents.
  #
  # Automatically sets +statuses: ["failed"]+ and +force: true+ so that
  # failed documents are reset to "pending" and requeued.
  #
  # @param knowledge_base_id [Integer, nil] specific KB to retry, or
  #   +nil+ to retry across ALL knowledge bases
  # @param options [Hash] additional options forwarded to {#perform}
  # @return [void]
  #
  # @example Retry failed documents in a specific KB
  #   BatchProcessDocumentsJob.retry_failed(42)
  #
  # @example Retry all failed documents across the entire system
  #   BatchProcessDocumentsJob.retry_failed
  def self.retry_failed(knowledge_base_id = nil, options = {})
    opts = options.merge(statuses: [ "failed" ], force: true)

    if knowledge_base_id
      perform_later(knowledge_base_id, opts)
    else
      KnowledgeBase.find_each do |kb|
        perform_later(kb.id, opts)
      end
    end
  end

  private

  # Query documents matching the configured status filter and limit.
  #
  # Orders by +created_at ASC+ so older documents are processed first
  # (FIFO fairness).
  #
  # @param knowledge_base [KnowledgeBase]
  # @return [ActiveRecord::Relation<Document>]
  def fetch_documents(knowledge_base)
    scope = knowledge_base.documents.where(status: @statuses)
    scope = scope.limit(@limit) if @limit.present?
    scope.order(created_at: :asc)
  end

  # Determine whether a document should be enqueued for processing.
  #
  # When +@force+ is true, everything is processed. Otherwise, skip
  # documents that are already being processed or already indexed.
  #
  # @param document [Document]
  # @return [Boolean]
  def should_process?(document)
    return true if @force
    return false if document.processing?
    return false if document.indexed?

    true
  end

  # Reset a failed document's status and enqueue a {ProcessDocumentJob}.
  #
  # When force-reprocessing, failed documents are reset to "pending"
  # so the child job doesn't skip them.
  #
  # @param document [Document]
  # @return [void]
  def enqueue_document(document)
    # Reset failed documents so ProcessDocumentJob doesn't see stale
    # "failed" status and skip them
    document.update!(status: "pending") if document.failed? && @force

    ProcessDocumentJob.perform_later(document.id, force: @force)
  end
end
