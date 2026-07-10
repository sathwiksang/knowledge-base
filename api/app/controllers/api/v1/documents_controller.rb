module Api
  module V1
    # Manages documents within a knowledge base — upload, view, delete,
    # and trigger (re)processing of document content into searchable chunks.
    #
    # == Resource hierarchy
    #
    #   User → KnowledgeBase → Document → Chunk (with embedding)
    #
    # == Routing
    #
    # Documents use a mix of nested and shallow routes:
    #
    #   Nested (require knowledge_base_id):
    #     GET    /api/v1/knowledge_bases/:kb_id/documents           → index
    #     POST   /api/v1/knowledge_bases/:kb_id/documents           → create
    #     POST   /api/v1/knowledge_bases/:kb_id/documents/batch_reprocess
    #
    #   Shallow (use document id directly):
    #     GET    /api/v1/documents/:id                              → show
    #     DELETE /api/v1/documents/:id                              → destroy
    #     POST   /api/v1/documents/:id/reprocess                   → reprocess
    #     GET    /api/v1/documents/:id/status                      → status
    #
    # == Document lifecycle (status field)
    #
    #   pending → processing → indexed   (happy path)
    #                        → failed    (error during chunking/embedding)
    #
    # When a document is created, it starts as "pending" and a background
    # job ({ProcessDocumentJob}) is enqueued to chunk the text, generate
    # embeddings, and store them. Poll the +/status+ endpoint to track
    # progress.
    #
    # == Authentication
    # All endpoints require a valid JWT token. Users can only access
    # documents inside their own knowledge bases.
    #
    # == Rate limiting
    # No rate limiting currently applied.
    #
    # @see DocumentProcessorService The service that processes documents
    # @see ProcessDocumentJob Background job that triggers processing
    # @see KnowledgeBasesController Parent resource controller
    class DocumentsController < BaseController
      before_action :set_knowledge_base, only: [ :index, :create, :batch_reprocess ]
      before_action :set_document, only: [ :show, :destroy, :reprocess, :status ]

      # ----------------------------------------------------------------
      # GET /api/v1/knowledge_bases/:knowledge_base_id/documents
      # ----------------------------------------------------------------
      # List all documents in a knowledge base, ordered by most recently
      # created first. Includes a +meta+ block with counts by status so
      # you can show a processing dashboard.
      #
      # == Parameters
      # - +knowledge_base_id+ [Integer] (path) — the parent knowledge base
      #
      # == Success response (200 OK)
      #   {
      #     "documents": [
      #       {
      #         "id": 1,
      #         "title": "Auth Guide",
      #         "status": "indexed",
      #         "created_at": "2026-01-01T00:00:00Z"
      #       }
      #     ],
      #     "meta": {
      #       "total": 10,
      #       "pending": 2,
      #       "processing": 1,
      #       "indexed": 6,
      #       "failed": 1
      #     },
      #     "request_id": "abc-123"
      #   }
      #
      # == Error responses
      # - 404 Not Found — knowledge base not found
      #
      # == Example curl
      #   curl -H "Authorization: Bearer <token>" \
      #        http://localhost:3000/api/v1/knowledge_bases/1/documents
      def index
        documents = @knowledge_base.documents.order(created_at: :desc)

        render_success({
          documents: DocumentBlueprint.render_as_hash(documents),
          meta: {
            total: documents.count,
            pending: documents.pending.count,
            processing: documents.processing.count,
            indexed: documents.indexed.count,
            failed: documents.failed.count
          }
        })
      end

      # ----------------------------------------------------------------
      # GET /api/v1/documents/:id
      # ----------------------------------------------------------------
      # Retrieve a single document with full details (including content
      # and chunk information in the detailed view).
      #
      # == Parameters
      # - +id+ [Integer] (path) — document ID
      #
      # == Success response (200 OK)
      #   {
      #     "document": {
      #       "id": 1,
      #       "title": "Auth Guide",
      #       "content": "Full document text...",
      #       "status": "indexed",
      #       "chunks_count": 8,
      #       "created_at": "2026-01-01T00:00:00Z"
      #     },
      #     "request_id": "abc-123"
      #   }
      #
      # == Error responses
      # - 404 Not Found — document not found or belongs to another user
      #
      # == Example curl
      #   curl -H "Authorization: Bearer <token>" \
      #        http://localhost:3000/api/v1/documents/1
      def show
        render_success({
          document: DocumentBlueprint.render_as_hash(@document, view: :detailed)
        })
      end

      # ----------------------------------------------------------------
      # GET /api/v1/documents/:id/status
      # ----------------------------------------------------------------
      # Lightweight endpoint to poll the processing status of a document.
      # Use this after creating a document to check when it finishes
      # processing.
      #
      # == Parameters
      # - +id+ [Integer] (path) — document ID
      #
      # == Success response (200 OK)
      #   {
      #     "id": 1,
      #     "status": "indexed",
      #     "chunks_count": 8,
      #     "error": null,
      #     "updated_at": "2026-01-01T00:00:00Z",
      #     "request_id": "abc-123"
      #   }
      #
      # When status is "failed", the +error+ field contains the reason:
      #   {
      #     "id": 1,
      #     "status": "failed",
      #     "chunks_count": 0,
      #     "error": "Embedding service is not available (Ollama may be offline)",
      #     "updated_at": "2026-01-01T00:05:00Z"
      #   }
      #
      # == Error responses
      # - 404 Not Found — document not found
      #
      # == Example curl
      #   curl -H "Authorization: Bearer <token>" \
      #        http://localhost:3000/api/v1/documents/1/status
      def status
        render_success({
          id: @document.id,
          status: @document.status,
          chunks_count: @document.chunks.count,
          error: @document.metadata["error"],
          updated_at: @document.updated_at.iso8601
        })
      end

      # ----------------------------------------------------------------
      # POST /api/v1/knowledge_bases/:knowledge_base_id/documents
      # ----------------------------------------------------------------
      # Upload a new document to a knowledge base. The document is saved
      # immediately and a background job is enqueued to process it
      # (chunk the text and generate embeddings).
      #
      # The document starts with status "pending". Use the +/status+
      # endpoint to poll until it becomes "indexed" or "failed".
      #
      # == Parameters
      # - +knowledge_base_id+ [Integer] (path) — the parent knowledge base
      #
      # == Required parameters (JSON body)
      # - +title+   [String] — document title
      # - +content+ [String] — the full document text (min 50 characters)
      #
      # == Optional parameters (JSON body)
      # - +metadata+ [Object] — arbitrary key-value metadata to attach
      #
      # == Success response (201 Created)
      #   {
      #     "document": {
      #       "id": 1,
      #       "title": "Auth Guide",
      #       "status": "pending",
      #       "created_at": "2026-01-01T00:00:00Z"
      #     },
      #     "message": "Document uploaded successfully. Processing will begin shortly.",
      #     "request_id": "abc-123"
      #   }
      #
      # If the background queue is temporarily unavailable, a +warning+
      # field is included but the document is still saved:
      #   { ..., "warning": "Background processing queue is temporarily unavailable..." }
      #
      # == Error responses
      # - 404 Not Found — knowledge base not found
      # - 422 Unprocessable Entity — validation failed (missing title, content too short)
      #
      # == Example curl
      #   curl -X POST http://localhost:3000/api/v1/knowledge_bases/1/documents \
      #        -H "Authorization: Bearer <token>" \
      #        -H "Content-Type: application/json" \
      #        -d '{"title":"Auth Guide","content":"Long document text here..."}'
      def create
        document = @knowledge_base.documents.build(document_params)

        if document.save
          queue_warning = enqueue_processing(document.id)

          response_data = {
            document: DocumentBlueprint.render_as_hash(document),
            message: "Document uploaded successfully. Processing will begin shortly."
          }
          response_data[:warning] = queue_warning if queue_warning

          render_success(response_data, status: :created)
        else
          render_unprocessable(document.errors.full_messages)
        end
      end

      # ----------------------------------------------------------------
      # POST /api/v1/documents/:id/reprocess
      # ----------------------------------------------------------------
      # Re-process an existing document — resets its status to "pending",
      # clears any previous error, and enqueues a new processing job.
      # Existing chunks are destroyed and recreated from scratch.
      #
      # Useful when:
      # - A document previously failed due to Ollama being offline
      # - You want to regenerate embeddings after a model change
      #
      # == Parameters
      # - +id+ [Integer] (path) — document ID
      #
      # == Success response (200 OK)
      #   {
      #     "document": { "id": 1, "status": "pending", ... },
      #     "message": "Document queued for reprocessing",
      #     "request_id": "abc-123"
      #   }
      #
      # == Error responses
      # - 404 Not Found — document not found
      # - 422 Unprocessable Entity — document is currently being processed
      #     { "error": "validation_failed", "errors": ["Document is already being processed"], ... }
      #
      # == Example curl
      #   curl -X POST http://localhost:3000/api/v1/documents/1/reprocess \
      #        -H "Authorization: Bearer <token>"
      def reprocess
        if @document.processing?
          render_unprocessable([ "Document is already being processed" ])
          return
        end

        @document.update!(status: "pending", metadata: @document.metadata.except("error"))

        queue_warning = enqueue_processing(@document.id, force: true)

        response_data = {
          document: DocumentBlueprint.render_as_hash(@document),
          message: "Document queued for reprocessing"
        }
        response_data[:warning] = queue_warning if queue_warning

        render_success(response_data)
      end

      # ----------------------------------------------------------------
      # POST /api/v1/knowledge_bases/:knowledge_base_id/documents/batch_reprocess
      # ----------------------------------------------------------------
      # Queue ALL documents matching the given statuses for reprocessing.
      # Useful for recovering from bulk failures (e.g. after Ollama was
      # restarted).
      #
      # == Parameters
      # - +knowledge_base_id+ [Integer] (path) — the parent knowledge base
      #
      # == Optional parameters (JSON body)
      # - +statuses+ [Array<String>] — which document statuses to reprocess
      #   (default: +["pending", "failed"]+). Valid values: "pending",
      #   "processing", "indexed", "failed".
      # - +force+ [Boolean] — if true, also reprocess already-indexed
      #   documents (default: false)
      #
      # == Success response (200 OK)
      #   {
      #     "message": "Batch reprocessing queued for 5 documents",
      #     "knowledge_base_id": 1,
      #     "statuses": ["pending", "failed"],
      #     "documents_count": 5,
      #     "request_id": "abc-123"
      #   }
      #
      # == Error responses
      # - 404 Not Found — knowledge base not found
      #
      # == Example curl
      #   curl -X POST http://localhost:3000/api/v1/knowledge_bases/1/documents/batch_reprocess \
      #        -H "Authorization: Bearer <token>" \
      #        -H "Content-Type: application/json" \
      #        -d '{"statuses":["failed"],"force":true}'
      def batch_reprocess
        statuses = params[:statuses] || [ "pending", "failed" ]
        force = params[:force] == true || params[:force] == "true"

        documents_count = @knowledge_base.documents.where(status: statuses).count

        queue_warning = nil
        begin
          BatchProcessDocumentsJob.perform_later(
            @knowledge_base.id,
            statuses: statuses,
            force: force
          )
        rescue SolidQueue::Job::EnqueueError => e
          Rails.logger.error("[DocumentsController] Failed to enqueue batch reprocess: #{e.message}")
          queue_warning = "Background queue is temporarily unavailable. Batch processing will be retried automatically."
        end

        response_data = {
          message: "Batch reprocessing queued for #{documents_count} documents",
          knowledge_base_id: @knowledge_base.id,
          statuses: statuses,
          documents_count: documents_count
        }
        response_data[:warning] = queue_warning if queue_warning

        render_success(response_data)
      end

      # ----------------------------------------------------------------
      # DELETE /api/v1/documents/:id
      # ----------------------------------------------------------------
      # Permanently delete a document and all its chunks/embeddings.
      # Cannot delete a document that is currently being processed —
      # wait for it to finish or fail first.
      #
      # == Parameters
      # - +id+ [Integer] (path) — document ID
      #
      # == Success response (200 OK)
      #   { "message": "Document deleted successfully", "request_id": "abc-123" }
      #
      # == Error responses
      # - 404 Not Found — document not found
      # - 422 Unprocessable Entity — document is currently being processed
      #
      # == Example curl
      #   curl -X DELETE http://localhost:3000/api/v1/documents/1 \
      #        -H "Authorization: Bearer <token>"
      def destroy
        if @document.processing?
          render_unprocessable([ "Cannot delete document while it is being processed" ])
          return
        end

        @document.destroy
        render_success({ message: "Document deleted successfully" })
      end

      private

      # Load the knowledge base from the nested route param, scoped to
      # the current user.
      #
      # @raise renders 404 if not found
      def set_knowledge_base
        @knowledge_base = current_user.knowledge_bases.find(params[:knowledge_base_id])
      rescue ActiveRecord::RecordNotFound
        render_not_found("Knowledge base")
      end

      # Load a document by ID, ensuring it belongs to a knowledge base
      # owned by the current user (via JOIN).
      #
      # @raise renders 404 if not found or not owned
      def set_document
        @document = Document.joins(:knowledge_base)
                           .where(knowledge_bases: { user_id: current_user.id })
                           .find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found("Document")
      end

      # Strong parameters for document creation.
      #
      # @return [ActionController::Parameters] permitted: +title+, +content+,
      #   +metadata+ (Hash)
      def document_params
        params.permit(:title, :content, metadata: {})
      end

      # Enqueue a background job to process the document (chunk + embed).
      # Returns nil on success, or a warning string if the queue is unavailable.
      #
      # @param document_id [Integer] the document to process
      # @param options [Hash] forwarded to the job (e.g. +force: true+)
      # @return [String, nil] warning message if queue is down, nil on success
      def enqueue_processing(document_id, **options)
        ProcessDocumentJob.perform_later(document_id, **options)
        nil
      rescue SolidQueue::Job::EnqueueError => e
        Rails.logger.error(
          "[DocumentsController] Failed to enqueue ProcessDocumentJob for document #{document_id}: #{e.message}"
        )
        "Background processing queue is temporarily unavailable. " \
          "The document has been saved and will be processed when the queue recovers."
      end
    end
  end
end
