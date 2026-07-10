# Represents a single document uploaded to a {KnowledgeBase}.
#
# Documents hold the raw text content that users upload. After creation,
# a background job ({ProcessDocumentJob}) picks up the document and runs
# it through the processing pipeline ({DocumentProcessorService}):
#
#   1. Text is split into overlapping {Chunk}s by {TextChunkerService}
#   2. Each chunk is embedded into a 768-dim vector by {EmbeddingService}
#   3. Chunks are saved with their embeddings for vector search
#
# == Lifecycle (status field)
#
#   pending  →  processing  →  indexed   (happy path)
#                            →  failed    (error during processing)
#
# - **pending**    — saved but not yet picked up by the background job
# - **processing** — currently being chunked and embedded
# - **indexed**    — all chunks created successfully; ready for search
# - **failed**     — processing failed; error stored in +metadata["error"]+
#
# A failed document can be re-processed via the +/reprocess+ endpoint,
# which resets its status to "pending" and enqueues a new job.
#
# == Table: +documents+
#
# @!attribute [r] id
#   @return [Integer] primary key (auto-increment)
# @!attribute [rw] title
#   @return [String] human-readable title (max 255 chars, NOT NULL)
# @!attribute [rw] content
#   @return [String] the full document text (NOT NULL). Minimum 50
#     characters is enforced by {DocumentProcessorService}, not by
#     model validation, to keep the model layer lenient.
# @!attribute [rw] status
#   @return [String] processing lifecycle state. One of: "pending",
#     "processing", "indexed", "failed". Defaults to "pending".
#     (indexed, NOT NULL)
# @!attribute [rw] metadata
#   @return [Hash] arbitrary JSONB metadata. When processing fails,
#     the error message is stored under the +"error"+ key.
#     (GIN-indexed for fast JSON queries, defaults to +{}+)
# @!attribute [rw] knowledge_base_id
#   @return [Integer] foreign key to the parent {KnowledgeBase}
#     (indexed, NOT NULL)
# @!attribute [r] created_at
#   @return [DateTime]
# @!attribute [r] updated_at
#   @return [DateTime]
#
# @example Creating a document (triggers background processing)
#   doc = kb.documents.create!(title: "Auth Guide", content: "Long text...")
#   doc.status # => "pending"
#
# @example Checking processing result
#   doc.reload
#   doc.indexed?                # => true
#   doc.chunks.count            # => 8
#
# @example Inspecting a failure
#   doc.failed?                 # => true
#   doc.metadata["error"]       # => "Embedding service is not available"
#
# @see DocumentProcessorService Runs the chunking + embedding pipeline
# @see ProcessDocumentJob Background job that triggers processing
# @see Api::V1::DocumentsController CRUD and reprocessing endpoints
class Document < ApplicationRecord
  # @!method knowledge_base
  #   @return [KnowledgeBase] the knowledge base this document belongs to.
  #     Required — every document must live inside a KB.
  belongs_to :knowledge_base

  # @!method chunks
  #   @return [ActiveRecord::Associations::CollectionProxy<Chunk>]
  #     the text chunks created during processing. Destroying the
  #     document cascades to destroy all its chunks and their embeddings.
  has_many :chunks, dependent: :destroy

  # @return [Array<String>] the four valid status values for the
  #   processing lifecycle. Used by the +status+ inclusion validation.
  STATUSES = %w[pending processing indexed failed].freeze

  # Title is required and capped at 255 chars (matches DB column limit).
  validates :title, presence: true, length: { maximum: 255 }

  # Content is required — the actual text that gets chunked and embedded.
  validates :content, presence: true

  # Status must be one of the STATUSES values. Defaults to "pending" at
  # the database level.
  validates :status, presence: true, inclusion: { in: STATUSES }

  # @!group Scopes
  # Convenience scopes for filtering documents by processing status.
  # Used by controllers to build status dashboards and by
  # {BatchProcessDocumentsJob} to find documents to reprocess.

  # @!method self.pending
  #   @return [ActiveRecord::Relation<Document>] documents awaiting processing
  scope :pending, -> { where(status: "pending") }

  # @!method self.processing
  #   @return [ActiveRecord::Relation<Document>] documents currently being processed
  scope :processing, -> { where(status: "processing") }

  # @!method self.indexed
  #   @return [ActiveRecord::Relation<Document>] documents that are fully indexed and searchable
  scope :indexed, -> { where(status: "indexed") }

  # @!method self.failed
  #   @return [ActiveRecord::Relation<Document>] documents where processing failed
  scope :failed, -> { where(status: "failed") }

  # @!endgroup

  # @!group Status predicates
  # Boolean methods to check the current processing status.
  # Prefer these over string comparison (e.g. +doc.indexed?+ instead
  # of +doc.status == "indexed"+) for readability.

  # @return [Boolean] true if the document is waiting to be processed
  def pending?
    status == "pending"
  end

  # @return [Boolean] true if the document is currently being chunked/embedded
  def processing?
    status == "processing"
  end

  # @return [Boolean] true if the document has been fully indexed and is searchable
  def indexed?
    status == "indexed"
  end

  # @return [Boolean] true if processing failed (check +metadata["error"]+ for details)
  def failed?
    status == "failed"
  end

  # @!endgroup

  # @!group Status transitions
  # Methods to move the document through its processing lifecycle.
  # Each calls +update!+ so an exception is raised if the save fails.
  # Used by {DocumentProcessorService} during the processing pipeline.

  # Transition the document to "processing" status.
  # Called by {DocumentProcessorService#process} at the start of the pipeline.
  #
  # @return [Boolean] true on successful save
  # @raise [ActiveRecord::RecordInvalid] if the save fails
  def mark_processing!
    update!(status: "processing")
  end

  # Transition the document to "indexed" status.
  # Called by {DocumentProcessorService#process} after all chunks are created.
  #
  # @return [Boolean] true on successful save
  # @raise [ActiveRecord::RecordInvalid] if the save fails
  def mark_indexed!
    update!(status: "indexed")
  end

  # Transition the document to "failed" status and store the error message
  # in +metadata["error"]+ for later inspection.
  #
  # @param error_message [String, nil] human-readable description of what
  #   went wrong (e.g. "Ollama connection error: Connection refused")
  # @return [Boolean] true on successful save
  # @raise [ActiveRecord::RecordInvalid] if the save fails
  #
  # @example
  #   doc.mark_failed!("Embedding service is not available")
  #   doc.metadata["error"] # => "Embedding service is not available"
  def mark_failed!(error_message = nil)
    update!(
      status: "failed",
      metadata: metadata.merge("error" => error_message)
    )
  end

  # @!endgroup
end
