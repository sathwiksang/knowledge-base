# frozen_string_literal: true

# Processes a single {Document} through the full indexing pipeline:
# chunking the text, generating embeddings, and storing them as {Chunk}
# records.
#
# This is the most important background job in the application. It is the
# bridge between "user uploaded a document" and "document is searchable."
#
# == When it gets enqueued
#
# - **On document creation** — {Api::V1::DocumentsController#create}
#   enqueues this job immediately after saving the document.
# - **On reprocess** — {Api::V1::DocumentsController#reprocess} enqueues
#   it with +force: true+ to re-index an existing document.
# - **From batch job** — {BatchProcessDocumentsJob} enqueues one of these
#   per document when batch-reprocessing.
#
# == Queue
#
# Runs on the +:default+ queue (Solid Queue, backed by PostgreSQL).
#
# == Expected duration
#
# Depends on document length and hardware:
# - Short document (1–2 pages): 5–15 seconds
# - Medium document (5–10 pages): 15–60 seconds
# - Long document (50+ pages): 1–5 minutes
#
# Most time is spent on embedding generation (one Ollama API call per
# chunk). A 10-page document typically produces ~20 chunks.
#
# == Retry behaviour
#
# Different errors get different retry strategies:
#
# | Error                         | Attempts | Wait strategy        | Reason                              |
# |-------------------------------|----------|----------------------|-------------------------------------|
# | Ollama ConnectionError        | 10       | Polynomial backoff   | Ollama may be restarting            |
# | Ollama TimeoutError           | 5        | Polynomial backoff   | Server may be overloaded            |
# | Ollama ModelError             | 3        | Fixed 30s            | Usually persistent (wrong model)    |
# | EmbeddingError                | 5        | Polynomial backoff   | Transient Ollama issues             |
# | ProcessingError               | 3        | Polynomial backoff   | Unexpected failures                 |
# | RecordNotFound                | —        | Discarded            | Document was deleted                |
# | ValidationError               | —        | Discarded            | Content too short, won't fix itself |
#
# "Polynomial backoff" means: attempt 1 waits ~3s, attempt 2 waits ~18s,
# attempt 3 waits ~83s, and so on (wait = (executions ** 4) + 2).
#
# == Workflow
#
#   ┌─────────────────┐
#   │   Job starts    │
#   └────────┬────────┘
#            │
#            ▼
#   ┌─────────────────┐     yes    ┌──────────────────┐
#   │ Document exists? │───────────│ Already indexed?  │
#   └────────┬────────┘           └────────┬─────────┘
#            │ no                    yes &  │  no
#            ▼                  !force ▼    │
#   ┌────────────────┐     ┌────────────┐  │
#   │ Discard (404)  │     │ Skip (noop)│  │
#   └────────────────┘     └────────────┘  │
#                                          ▼
#                              ┌───────────────────────┐
#                              │ DocumentProcessorService│
#                              │   .process(document)    │
#                              └───────────┬───────────┘
#                                          │
#                           ┌──────────────┴──────────────┐
#                           │                             │
#                           ▼                             ▼
#                    ┌────────────┐               ┌────────────┐
#                    │  Success   │               │  Failure   │
#                    │ status:    │               │ status:    │
#                    │ "indexed"  │               │ "failed"   │
#                    └────────────┘               └─────┬──────┘
#                                                       │
#                                            ┌──────────┴──────────┐
#                                            │                     │
#                                            ▼                     ▼
#                                     ┌────────────┐       ┌────────────┐
#                                     │  Retryable │       │  Discarded │
#                                     │(Connection,│       │(Validation,│
#                                     │ Timeout,   │       │ NotFound)  │
#                                     │ Embedding) │       └────────────┘
#                                     └────────────┘
#
# == Database side effects
#
# On success:
# - Document status changes: "pending" → "processing" → "indexed"
# - Existing chunks are deleted (if reprocessing)
# - New {Chunk} records are created with embeddings
#
# On failure:
# - Document status changes to "failed"
# - Error message stored in +document.metadata["error"]+
# - No chunks are created (or partial chunks may exist if failure
#   occurred mid-processing)
#
# @example Enqueue for a newly created document
#   ProcessDocumentJob.perform_later(document.id)
#
# @example Enqueue with force-reprocess
#   ProcessDocumentJob.perform_later(document.id, force: true)
#
# @example Enqueue with high priority (processed before normal jobs)
#   ProcessDocumentJob.perform_urgent(document.id)
#
# @example Monitor job status via Rails console
#   # Check Solid Queue's job table for pending jobs:
#   SolidQueue::Job.where(class_name: "ProcessDocumentJob").count
#
#   # Check the document's status to see if the job completed:
#   Document.find(1).status # => "indexed" or "failed"
#
# @see DocumentProcessorService The service that does the actual work
# @see BatchProcessDocumentsJob Enqueues many of these at once
# @see Api::V1::DocumentsController#create Enqueues on document upload
class ProcessDocumentJob < ApplicationJob
  queue_as :default

  # @return [Integer] priority value for urgent processing (lower = higher priority).
  #   Use via {.perform_urgent} for user-initiated reprocessing.
  PRIORITY_HIGH = 0

  # @return [Integer] default priority value for standard document processing.
  PRIORITY_NORMAL = 10

  # @return [Integer] priority value for background/bulk processing.
  PRIORITY_LOW = 20

  # --- Retry configuration ---
  # Each error type has a tailored retry strategy based on how likely it
  # is to be transient vs. permanent.

  # Ollama is not running. Retry aggressively (10 attempts) because it
  # may be restarting or temporarily down.
  retry_on Clients::OllamaClient::ConnectionError,
           wait: :polynomially_longer,
           attempts: 10

  # Ollama started responding but timed out. Retry moderately — the
  # server may be overloaded with other requests.
  retry_on Clients::OllamaClient::TimeoutError,
           wait: :polynomially_longer,
           attempts: 5

  # Ollama returned an error (e.g. model not found). Retry only a few
  # times with a short wait — this is usually a configuration issue
  # that won't resolve on its own.
  retry_on Clients::OllamaClient::ModelError,
           wait: 30.seconds,
           attempts: 3

  # Embedding generation failed partway through. Retry with backoff —
  # this can be a transient Ollama issue.
  retry_on DocumentProcessorService::EmbeddingError,
           wait: :polynomially_longer,
           attempts: 5

  # Unexpected processing error. Retry a few times in case it was a
  # transient issue (e.g. temporary disk full, race condition).
  retry_on DocumentProcessorService::ProcessingError,
           wait: :polynomially_longer,
           attempts: 3

  # Document was deleted between enqueue and execution — nothing to
  # process, so discard permanently.
  discard_on ActiveRecord::RecordNotFound

  # Validation failures (content too short, already indexed without
  # force flag, etc.) won't fix themselves on retry — discard.
  discard_on DocumentProcessorService::ValidationError

  # --- Lifecycle callbacks for logging/monitoring ---
  before_enqueue :log_enqueue
  before_perform :log_start
  after_perform :log_completion

  # Process a single document through the indexing pipeline.
  #
  # Loads the document from the database, checks whether it should be
  # processed (skip if already indexed or currently processing), then
  # delegates to {DocumentProcessorService} for the actual work.
  #
  # @param document_id [Integer] the ID of the {Document} to process
  # @param options [Hash] processing options
  # @option options [Boolean] :force (false) if +true+, reprocess even
  #   if the document is already indexed or currently processing.
  #   Existing chunks are destroyed and recreated.
  # @return [DocumentProcessorService::ProcessingResult] the processing
  #   outcome (success/failure, chunk count, timing)
  #
  # @raise [Clients::OllamaClient::ConnectionError] re-raised for retry
  # @raise [Clients::OllamaClient::TimeoutError] re-raised for retry
  # @raise [DocumentProcessorService::EmbeddingError] re-raised for retry
  def perform(document_id, options = {})
    @document_id = document_id
    @options = options.symbolize_keys
    @force_reprocess = @options[:force] || false

    document = Document.find(document_id)

    # Guard: skip if already indexed (unless explicitly forced)
    if document.indexed? && !@force_reprocess
      Rails.logger.info("[ProcessDocumentJob] Document #{document_id} already indexed, skipping")
      return
    end

    # Guard: prevent duplicate concurrent processing of the same document
    if document.processing? && !@force_reprocess
      Rails.logger.info("[ProcessDocumentJob] Document #{document_id} currently processing, skipping")
      return
    end

    # Delegate to the service — this is where chunking + embedding happens
    result = DocumentProcessorService.process(document)

    if result.success?
      Rails.logger.info(
        "[ProcessDocumentJob] Document #{document_id} processed successfully: " \
        "#{result.chunks_created} chunks in #{result.processing_time}s"
      )
    else
      Rails.logger.warn(
        "[ProcessDocumentJob] Document #{document_id} processing failed: #{result.error_message}"
      )
    end

    result
  end

  # Enqueue the job with a custom Solid Queue priority.
  #
  # Lower priority values are processed first. Use the +PRIORITY_*+
  # constants for standard levels.
  #
  # @param document_id [Integer] the document to process
  # @param priority [Integer] queue priority (default: {PRIORITY_NORMAL})
  # @param options [Hash] forwarded to {#perform} (e.g. +force: true+)
  # @return [ProcessDocumentJob] the enqueued job instance
  #
  # @example
  #   ProcessDocumentJob.perform_with_priority(doc.id, priority: ProcessDocumentJob::PRIORITY_LOW)
  def self.perform_with_priority(document_id, priority: PRIORITY_NORMAL, **options)
    set(priority: priority).perform_later(document_id, options)
  end

  # Convenience method to enqueue with highest priority.
  #
  # Use for user-initiated reprocessing where the user is actively
  # waiting for the result.
  #
  # @param document_id [Integer] the document to process
  # @param options [Hash] forwarded to {#perform}
  # @return [ProcessDocumentJob] the enqueued job instance
  #
  # @example
  #   ProcessDocumentJob.perform_urgent(doc.id, force: true)
  def self.perform_urgent(document_id, **options)
    perform_with_priority(document_id, priority: PRIORITY_HIGH, **options)
  end

  private

  # @!group Lifecycle logging callbacks

  def log_enqueue
    Rails.logger.info("[ProcessDocumentJob] Enqueuing job for document #{arguments.first}")
  end

  def log_start
    Rails.logger.info("[ProcessDocumentJob] Starting processing for document #{arguments.first}")
  end

  def log_completion
    Rails.logger.info("[ProcessDocumentJob] Completed job for document #{arguments.first}")
  end

  # @!endgroup
end
