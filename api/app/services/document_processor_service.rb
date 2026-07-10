# frozen_string_literal: true

# Orchestrates the full document indexing pipeline: validation, chunking,
# embedding generation, and persistence.
#
# This is the primary entry point for turning a raw {Document} into
# searchable vector-indexed content. The pipeline flow is:
#
# 1. **Validate** — ensure the document has sufficient content and the
#    embedding service (Ollama) is online
# 2. **Chunk** — split the document text into overlapping segments via
#    {TextChunkerService}
# 3. **Embed** — generate a 768-dim vector for each chunk via
#    {EmbeddingService} (with automatic retry on transient failures)
# 4. **Persist** — save each {Chunk} record with its embedding
# 5. **Update status** — mark the document as +indexed+ (or +failed+)
#
# @note Embedding and Ollama errors are re-raised after marking the
#   document as failed, so that background job frameworks (Solid Queue)
#   can retry with backoff. Validation and chunking errors return a
#   failure result without re-raising.
# @note Safe for reprocessing — existing chunks are destroyed before
#   new ones are created.
#
# @example Process a single document
#   result = DocumentProcessorService.process(document)
#   if result.success?
#     puts "Created #{result.chunks_created} chunks in #{result.processing_time}s"
#   else
#     puts "Failed: #{result.error_message}"
#   end
#
# @example Process with custom dependencies (useful in tests)
#   service = DocumentProcessorService.new(
#     document:          doc,
#     chunker:           TextChunkerService.new(chunk_size: 300),
#     embedding_service: EmbeddingService.new(client: mock_client)
#   )
#   result = service.process
#
# @example Batch-process multiple documents
#   results = DocumentProcessorService.process_batch(Document.pending)
#   results.select(&:failed?).each { |r| notify_admin(r.error_message) }
#
# @see TextChunkerService Handles text splitting
# @see EmbeddingService Handles vector generation
# @see DocumentProcessingJob Background job that calls this service
class DocumentProcessorService
  # Base error class for all processing failures.
  class ProcessingError < StandardError; end

  # Raised when text chunking fails.
  class ChunkingError < ProcessingError; end

  # Raised when embedding generation or chunk persistence fails.
  class EmbeddingError < ProcessingError; end

  # Raised when pre-processing validation checks fail.
  class ValidationError < ProcessingError; end

  # Encapsulates the outcome of a processing attempt with success/failure
  # status, timing, and error details.
  #
  # @!attribute [rw] success
  #   @return [Boolean] whether processing completed without errors
  # @!attribute [rw] document
  #   @return [Document] the processed document
  # @!attribute [rw] chunks_created
  #   @return [Integer] number of chunks successfully created
  # @!attribute [rw] processing_time
  #   @return [Float] elapsed seconds
  # @!attribute [rw] error_message
  #   @return [String, nil] human-readable error description, or nil on success
  ProcessingResult = Struct.new(:success, :document, :chunks_created, :processing_time, :error_message, keyword_init: true) do
    # @return [Boolean] true if processing succeeded
    def success?
      success
    end

    # @return [Boolean] true if processing failed
    def failed?
      !success
    end
  end

  # @return [Integer] documents with fewer characters than this are rejected
  MINIMUM_CONTENT_LENGTH = 50

  # @return [Integer] maximum embedding generation attempts per chunk
  MAX_RETRIES_PER_CHUNK = 3

  # @return [Integer] base delay in seconds between retry attempts (multiplied by attempt number)
  RETRY_DELAY = 1

  # Create a new processor for a specific document.
  #
  # @param document [Document] the document to process
  # @param chunker [TextChunkerService, nil] text splitter (default: new instance)
  # @param embedding_service [EmbeddingService, nil] embedding generator
  #   (default: new instance)
  # @param logger [Logger, nil] logger for progress/error messages
  #   (default: +Rails.logger+)
  def initialize(document:, chunker: nil, embedding_service: nil, logger: nil)
    @document = document
    @chunker = chunker || TextChunkerService.new
    @embedding_service = embedding_service || EmbeddingService.new
    @logger = logger || Rails.logger
    @start_time = nil
  end

  # Execute the full processing pipeline for the document.
  #
  # Runs validation, chunking, embedding, and persistence in sequence.
  # On success the document is marked as +indexed+. On failure it is
  # marked as +failed+ with an error message.
  #
  # @return [ProcessingResult] outcome with chunk count, timing, and any error
  # @raise [EmbeddingError] re-raised after marking failed (for job retry)
  # @raise [Clients::OllamaClient::ConnectionError] re-raised for job retry
  # @raise [Clients::OllamaClient::OllamaError] re-raised for job retry
  # @raise [ProcessingError] wraps unexpected errors (for job retry)
  #
  # @example
  #   result = DocumentProcessorService.new(document: doc).process
  #   result.success?       # => true
  #   result.chunks_created # => 8
  def process
    @start_time = Time.current

    return build_failure_result("Document is nil") if @document.nil?

    log_info("Starting document processing: #{@document.title}")

    validate_document!

    @document.mark_processing!

    cleanup_existing_chunks

    chunk_data = chunk_document

    chunks_created = create_chunks_with_embeddings(chunk_data)

    @document.mark_indexed!

    log_info("Successfully indexed document with #{chunks_created} chunks in #{processing_time}s")

    ProcessingResult.new(
      success: true,
      document: @document,
      chunks_created: chunks_created,
      processing_time: processing_time,
      error_message: nil
    )
  rescue ValidationError => e
    handle_validation_error(e)
  rescue ChunkingError => e
    handle_chunking_error(e)
  rescue EmbeddingError => e
    handle_embedding_error(e)
  rescue Clients::OllamaClient::ConnectionError => e
    handle_ollama_connection_error(e)
  rescue Clients::OllamaClient::OllamaError => e
    handle_ollama_error(e)
  rescue StandardError => e
    handle_unexpected_error(e)
  end

  # Convenience class method to process a document in one call.
  #
  # @param document [Document] the document to process
  # @param options [Hash] keyword arguments forwarded to {#initialize}
  # @return [ProcessingResult]
  #
  # @example
  #   DocumentProcessorService.process(document)
  def self.process(document, **options)
    new(document: document, **options).process
  end

  # Process multiple documents sequentially, returning a result for each.
  #
  # @param documents [Array<Document>] documents to process
  # @param options [Hash] keyword arguments forwarded to {#initialize}
  # @return [Array<ProcessingResult>] one result per document
  #
  # @example
  #   results = DocumentProcessorService.process_batch(Document.pending)
  def self.process_batch(documents, **options)
    documents.map do |document|
      process(document, **options)
    end
  end

  private

  # Verify the document is in a valid state for processing.
  #
  # @raise [ValidationError] if any check fails
  # @return [true]
  def validate_document!
    raise ValidationError, "Document is nil" if @document.nil?
    raise ValidationError, "Document has no content" if @document.content.blank?
    raise ValidationError, "Document content too short (minimum #{MINIMUM_CONTENT_LENGTH} characters)" if @document.content.length < MINIMUM_CONTENT_LENGTH
    raise ValidationError, "Document is already indexed" if @document.indexed?
    raise ValidationError, "Document is currently being processed" if @document.processing?

    unless @embedding_service.available?
      raise ValidationError, "Embedding service is not available (Ollama may be offline)"
    end

    true
  end

  # Remove any existing chunks so the document can be reprocessed cleanly.
  def cleanup_existing_chunks
    existing_count = @document.chunks.count
    return if existing_count.zero?

    log_info("Removing #{existing_count} existing chunks for reprocessing")
    @document.chunks.destroy_all
  end

  # Split document content into chunk data using the configured chunker.
  #
  # @return [Array<Hash>] chunk hashes with +:content+ and +:index+ keys
  # @raise [ChunkingError] if chunking produces no results
  def chunk_document
    log_info("Chunking document content (#{@document.content.length} characters)")

    chunk_data = @chunker.chunk(@document.content)

    if chunk_data.empty?
      raise ChunkingError, "Document content could not be chunked (may be too short or contain only whitespace)"
    end

    log_info("Created #{chunk_data.length} chunks")
    chunk_data
  rescue TextChunkerService::ChunkerError => e
    raise ChunkingError, "Chunking failed: #{e.message}"
  end

  # Generate embeddings for each chunk and persist them as Chunk records.
  #
  # @param chunk_data [Array<Hash>] chunks from {#chunk_document}
  # @return [Integer] number of chunks successfully created
  # @raise [EmbeddingError] if embedding generation or DB save fails
  def create_chunks_with_embeddings(chunk_data)
    chunks_created = 0
    total_chunks = chunk_data.length

    chunk_data.each_with_index do |chunk_info, index|
      log_debug("Processing chunk #{index + 1}/#{total_chunks}")

      embedding = generate_embedding_with_retry(chunk_info[:content], index)

      @document.chunks.create!(
        content: chunk_info[:content],
        chunk_index: chunk_info[:index],
        embedding: embedding
      )

      chunks_created += 1
    rescue ActiveRecord::RecordInvalid => e
      raise EmbeddingError, "Failed to save chunk #{index}: #{e.message}"
    end

    chunks_created
  end

  # Generate an embedding with exponential-backoff retry on transient failures.
  #
  # @param content [String] chunk text to embed
  # @param chunk_index [Integer] chunk position (for error messages)
  # @return [Array<Float>] the embedding vector
  # @raise [EmbeddingError] after exhausting all retries
  def generate_embedding_with_retry(content, chunk_index)
    retries = 0

    begin
      embedding = @embedding_service.generate(content)

      if embedding.nil? || embedding.empty?
        raise EmbeddingError, "Empty embedding returned for chunk #{chunk_index}"
      end

      embedding
    rescue EmbeddingService::EmbeddingError => e
      retries += 1
      if retries <= MAX_RETRIES_PER_CHUNK
        log_warn("Embedding generation failed for chunk #{chunk_index}, retry #{retries}/#{MAX_RETRIES_PER_CHUNK}: #{e.message}")
        sleep(RETRY_DELAY * retries)
        retry
      end
      raise EmbeddingError, "Failed to generate embedding for chunk #{chunk_index} after #{MAX_RETRIES_PER_CHUNK} retries: #{e.message}"
    end
  end

  # @!group Error Handlers
  # Each handler logs the error, marks the document as failed, and either
  # returns a failure result (for non-retryable errors) or re-raises
  # (for errors that should trigger job-level retry).

  def handle_validation_error(error)
    log_error("Validation failed: #{error.message}")
    mark_failed(error.message)
    build_failure_result(error.message)
  end

  def handle_chunking_error(error)
    log_error("Chunking failed: #{error.message}")
    mark_failed("Chunking error: #{error.message}")
    build_failure_result(error.message)
  end

  def handle_embedding_error(error)
    log_error("Embedding failed: #{error.message}")
    mark_failed("Embedding error: #{error.message}")
    # Re-raise so Solid Queue can retry with backoff
    raise error
  end

  def handle_ollama_connection_error(error)
    log_error("Ollama connection error: #{error.message}")
    mark_failed("Ollama connection error: #{error.message}")
    # Re-raise so Solid Queue can retry with backoff
    raise error
  end

  def handle_ollama_error(error)
    log_error("Ollama error: #{error.message}")
    mark_failed("Ollama error: #{error.message}")
    # Re-raise so Solid Queue can retry
    raise error
  end

  def handle_unexpected_error(error)
    log_error("Unexpected error: #{error.class.name}: #{error.message}")
    log_error(error.backtrace&.first(10)&.join("\n"))
    mark_failed("Unexpected error: #{error.message}")
    # Re-raise so Solid Queue can retry
    raise ProcessingError, "Document processing failed: #{error.message}"
  end

  # @!endgroup

  # Safely transition the document to the failed state.
  # Swallows errors to avoid masking the original failure.
  #
  # @param message [String] failure reason stored on the document
  def mark_failed(message)
    return unless @document&.persisted?

    @document.mark_failed!(message)
  rescue StandardError => e
    log_error("Failed to mark document as failed: #{e.message}")
  end

  # Build a failure {ProcessingResult} with the given error message.
  #
  # @param error_message [String] human-readable description of what went wrong
  # @return [ProcessingResult]
  def build_failure_result(error_message)
    ProcessingResult.new(
      success: false,
      document: @document,
      chunks_created: 0,
      processing_time: processing_time,
      error_message: error_message
    )
  end

  # Calculate elapsed seconds since processing started.
  #
  # @return [Float] seconds elapsed, rounded to 2 decimal places
  def processing_time
    return 0 unless @start_time

    (Time.current - @start_time).round(2)
  end

  # @!group Logging Helpers

  # @param message [String]
  def log_info(message)
    @logger.info("[DocumentProcessor] Document #{@document&.id}: #{message}")
  end

  # @param message [String]
  def log_debug(message)
    @logger.debug("[DocumentProcessor] Document #{@document&.id}: #{message}")
  end

  # @param message [String]
  def log_warn(message)
    @logger.warn("[DocumentProcessor] Document #{@document&.id}: #{message}")
  end

  # @param message [String]
  def log_error(message)
    @logger.error("[DocumentProcessor] Document #{@document&.id}: #{message}")
  end

  # @!endgroup
end
