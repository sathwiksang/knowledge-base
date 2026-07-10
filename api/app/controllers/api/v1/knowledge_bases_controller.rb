module Api
  module V1
    # Manages Knowledge Base resources — the top-level containers that hold
    # documents. Also exposes semantic search and RAG-powered Q&A endpoints
    # scoped to a single knowledge base.
    #
    # == Resource hierarchy
    #
    #   User → KnowledgeBase → Document → Chunk (with embedding)
    #
    # A user can have many knowledge bases. Each knowledge base contains
    # documents that are chunked and embedded for vector search.
    #
    # == Authentication
    # All endpoints require a valid JWT token in the +Authorization+ header.
    # Users can only access their own knowledge bases (owner-scoped).
    #
    # == Rate limiting
    # No rate limiting currently applied. The +search+ and +ask+ endpoints
    # make calls to Ollama, so response times depend on LLM/embedding
    # model speed.
    #
    # @see SearchService Powers the /search endpoint
    # @see RagService Powers the /ask endpoint
    # @see DocumentsController Manages documents within a knowledge base
    class KnowledgeBasesController < BaseController
      before_action :set_knowledge_base, only: [ :show, :update, :destroy, :search, :ask ]

      # ----------------------------------------------------------------
      # GET /api/v1/knowledge_bases
      # ----------------------------------------------------------------
      # List all knowledge bases belonging to the authenticated user,
      # ordered by most recently created first.
      #
      # == Parameters
      # None.
      #
      # == Success response (200 OK)
      #   {
      #     "knowledge_bases": [
      #       {
      #         "id": 1,
      #         "name": "Company Policies",
      #         "description": "Internal policy documents",
      #         "documents_count": 5,
      #         "indexed_documents": 4,
      #         "created_at": "2026-01-01T00:00:00Z"
      #       }
      #     ],
      #     "request_id": "abc-123"
      #   }
      #
      # == Example curl
      #   curl -H "Authorization: Bearer <token>" \
      #        http://localhost:3000/api/v1/knowledge_bases
      def index
        knowledge_bases = current_user.knowledge_bases.order(created_at: :desc)

        render_success({
          knowledge_bases: KnowledgeBaseBlueprint.render_as_hash(knowledge_bases, view: :with_stats)
        })
      end

      # ----------------------------------------------------------------
      # GET /api/v1/knowledge_bases/:id
      # ----------------------------------------------------------------
      # Retrieve a single knowledge base by ID, including document stats.
      #
      # == Parameters
      # - +id+ [Integer] (path) — knowledge base ID
      #
      # == Success response (200 OK)
      #   {
      #     "knowledge_base": {
      #       "id": 1,
      #       "name": "Company Policies",
      #       "description": "...",
      #       "documents_count": 5,
      #       "indexed_documents": 4,
      #       "created_at": "2026-01-01T00:00:00Z"
      #     },
      #     "request_id": "abc-123"
      #   }
      #
      # == Error responses
      # - 404 Not Found — knowledge base does not exist or belongs to another user
      #
      # == Example curl
      #   curl -H "Authorization: Bearer <token>" \
      #        http://localhost:3000/api/v1/knowledge_bases/1
      def show
        render_success({
          knowledge_base: KnowledgeBaseBlueprint.render_as_hash(@knowledge_base, view: :with_stats)
        })
      end

      # ----------------------------------------------------------------
      # POST /api/v1/knowledge_bases
      # ----------------------------------------------------------------
      # Create a new, empty knowledge base for the authenticated user.
      # After creation, upload documents via the Documents endpoint.
      #
      # == Required parameters (JSON body)
      # - +name+ [String] — a unique name for the knowledge base
      #
      # == Optional parameters (JSON body)
      # - +description+ [String] — a short description of what this KB contains
      #
      # == Success response (201 Created)
      #   {
      #     "knowledge_base": {
      #       "id": 1,
      #       "name": "Company Policies",
      #       "description": "Internal policy documents",
      #       "created_at": "2026-01-01T00:00:00Z"
      #     },
      #     "request_id": "abc-123"
      #   }
      #
      # == Error responses
      # - 422 Unprocessable Entity — validation failed (e.g. blank name)
      #     { "error": "validation_failed", "errors": ["Name can't be blank"], ... }
      #
      # == Example curl
      #   curl -X POST http://localhost:3000/api/v1/knowledge_bases \
      #        -H "Authorization: Bearer <token>" \
      #        -H "Content-Type: application/json" \
      #        -d '{"name":"Company Policies","description":"Internal policy documents"}'
      def create
        knowledge_base = current_user.knowledge_bases.build(knowledge_base_params)

        if knowledge_base.save
          render_success(
            { knowledge_base: KnowledgeBaseBlueprint.render_as_hash(knowledge_base) },
            status: :created
          )
        else
          render_unprocessable(knowledge_base.errors.full_messages)
        end
      end

      # ----------------------------------------------------------------
      # PATCH/PUT /api/v1/knowledge_bases/:id
      # ----------------------------------------------------------------
      # Update an existing knowledge base's name and/or description.
      #
      # == Parameters
      # - +id+ [Integer] (path) — knowledge base ID
      #
      # == Optional parameters (JSON body)
      # - +name+        [String] — new name
      # - +description+ [String] — new description
      #
      # == Success response (200 OK)
      #   {
      #     "knowledge_base": { "id": 1, "name": "Updated Name", ... },
      #     "request_id": "abc-123"
      #   }
      #
      # == Error responses
      # - 404 Not Found — knowledge base not found
      # - 422 Unprocessable Entity — validation failed
      #
      # == Example curl
      #   curl -X PATCH http://localhost:3000/api/v1/knowledge_bases/1 \
      #        -H "Authorization: Bearer <token>" \
      #        -H "Content-Type: application/json" \
      #        -d '{"name":"Updated Policies"}'
      def update
        if @knowledge_base.update(knowledge_base_params)
          render_success({
            knowledge_base: KnowledgeBaseBlueprint.render_as_hash(@knowledge_base, view: :with_stats)
          })
        else
          render_unprocessable(@knowledge_base.errors.full_messages)
        end
      end

      # ----------------------------------------------------------------
      # DELETE /api/v1/knowledge_bases/:id
      # ----------------------------------------------------------------
      # Permanently delete a knowledge base and ALL of its documents,
      # chunks, and embeddings. This action cannot be undone.
      #
      # == Parameters
      # - +id+ [Integer] (path) — knowledge base ID
      #
      # == Success response (200 OK)
      #   { "message": "Knowledge base deleted successfully", "request_id": "abc-123" }
      #
      # == Error responses
      # - 404 Not Found — knowledge base not found
      #
      # == Example curl
      #   curl -X DELETE http://localhost:3000/api/v1/knowledge_bases/1 \
      #        -H "Authorization: Bearer <token>"
      def destroy
        @knowledge_base.destroy
        render_success({ message: "Knowledge base deleted successfully" })
      end

      # ----------------------------------------------------------------
      # POST /api/v1/knowledge_bases/:id/search
      # ----------------------------------------------------------------
      # Perform a semantic (vector similarity) search across all indexed
      # documents in this knowledge base.
      #
      # How it works:
      # 1. The query text is converted to a 768-dim vector via EmbeddingService
      # 2. pgvector finds the nearest chunk embeddings by cosine distance
      # 3. Results are ranked by similarity score (1.0 = identical, 0.0 = unrelated)
      #
      # == Parameters
      # - +id+ [Integer] (path) — knowledge base ID
      #
      # == Required parameters (JSON body)
      # - +query+ [String] — the search query (2–1000 characters)
      #
      # == Optional parameters (JSON body)
      # - +limit+          [Integer] — max results to return (default: 5, max: 20)
      # - +min_similarity+  [Float]  — discard results below this score (0.0–1.0)
      #
      # == Success response (200 OK)
      #   {
      #     "results": [
      #       {
      #         "rank": 1,
      #         "chunk_id": 42,
      #         "content": "Relevant chunk text...",
      #         "similarity_score": 0.8723,
      #         "document_id": 5,
      #         "document_title": "Auth Guide",
      #         "chunk_index": 3
      #       }
      #     ],
      #     "query": "how does auth work",
      #     "total_chunks_searched": 150,
      #     "knowledge_base_id": 1,
      #     "search_time_ms": 45.23,
      #     "request_id": "abc-123"
      #   }
      #
      # == Error responses
      # - 404 Not Found — knowledge base not found
      # - 422 Unprocessable Entity — missing query, no indexed documents, or search failure
      #     { "error": "No indexed documents in this knowledge base",
      #       "hint": "Upload documents and wait for processing to complete", ... }
      #
      # == Example curl
      #   curl -X POST http://localhost:3000/api/v1/knowledge_bases/1/search \
      #        -H "Authorization: Bearer <token>" \
      #        -H "Content-Type: application/json" \
      #        -d '{"query":"how does authentication work?","limit":3}'
      def search
        query = params[:query]
        limit = params[:limit] || SearchService::DEFAULT_LIMIT
        min_similarity = params[:min_similarity]&.to_f

        if query.blank?
          render_unprocessable([ "Query parameter is required" ])
          return
        end

        if @knowledge_base.indexed_documents.zero?
          render json: {
            error: "No indexed documents in this knowledge base",
            hint: "Upload documents and wait for processing to complete",
            knowledge_base_id: @knowledge_base.id
          }, status: :unprocessable_entity
          return
        end

        search_service = SearchService.new(knowledge_base: @knowledge_base)
        response = search_service.search(
          query: query,
          limit: limit,
          min_similarity: min_similarity
        )

        if response.success?
          render_success(response.to_h)
        else
          render json: {
            error: response.error,
            query: query,
            knowledge_base_id: @knowledge_base.id
          }, status: :unprocessable_entity
        end
      end

      # ----------------------------------------------------------------
      # POST /api/v1/knowledge_bases/:id/ask
      # ----------------------------------------------------------------
      # Ask a natural-language question and get an AI-generated answer
      # grounded in the knowledge base's documents (RAG pipeline).
      #
      # How it works:
      # 1. The question is embedded and the top-N most similar chunks are retrieved
      # 2. Retrieved chunks are concatenated into a context string
      # 3. The context + question are sent to the LLM (llama3.2:3b via Ollama)
      # 4. The LLM generates an answer based ONLY on the provided context
      # 5. Source citations are included so you can verify the answer
      #
      # == Parameters
      # - +id+ [Integer] (path) — knowledge base ID
      #
      # == Required parameters (JSON body)
      # - +question+ [String] — the question to ask (3–1000 characters)
      #
      # == Optional parameters (JSON body)
      # - +num_chunks+      [Integer] — how many context chunks to retrieve
      #   (default: 5, max: 10). More chunks = more context but slower.
      # - +include_sources+  [Boolean] — include source citations in response
      #   (default: true). Set to false for faster responses.
      #
      # == Success response (200 OK)
      #   {
      #     "answer": "Authentication uses JWT tokens that expire after 24 hours...",
      #     "question": "How does authentication work?",
      #     "sources": [
      #       {
      #         "document_id": 5,
      #         "document_title": "Auth Guide",
      #         "chunk_id": 42,
      #         "chunk_index": 3,
      #         "content_preview": "JWT tokens are issued on login...",
      #         "similarity_score": 0.8723
      #       }
      #     ],
      #     "knowledge_base_id": 1,
      #     "model": "llama3.2:3b",
      #     "chunks_used": 3,
      #     "total_chunks_searched": 150,
      #     "processing_time_ms": 1234.56,
      #     "request_id": "abc-123"
      #   }
      #
      # == Error responses
      # - 404 Not Found — knowledge base not found
      # - 422 Unprocessable Entity — missing question, no indexed documents,
      #   search failure, or LLM generation failure
      #
      # == Example curl
      #   curl -X POST http://localhost:3000/api/v1/knowledge_bases/1/ask \
      #        -H "Authorization: Bearer <token>" \
      #        -H "Content-Type: application/json" \
      #        -d '{"question":"How does authentication work?","num_chunks":3}'
      def ask
        question = params[:question]
        num_chunks = params[:num_chunks] || RagService::DEFAULT_CONTEXT_CHUNKS
        include_sources = ActiveModel::Type::Boolean.new.cast(params.fetch(:include_sources, true))

        if question.blank?
          render_unprocessable([ "Question parameter is required" ])
          return
        end

        if @knowledge_base.indexed_documents.zero?
          render json: {
            error: "No indexed documents in this knowledge base",
            hint: "Upload documents and wait for processing to complete",
            knowledge_base_id: @knowledge_base.id
          }, status: :unprocessable_entity
          return
        end

        rag_service = RagService.new(knowledge_base: @knowledge_base)
        response = rag_service.ask(
          question: question,
          num_chunks: num_chunks,
          include_sources: include_sources
        )

        if response.success?
          render_success(response.to_h)
        else
          render json: {
            error: response.error,
            question: question,
            knowledge_base_id: @knowledge_base.id
          }, status: :unprocessable_entity
        end
      end

      private

      # Load the knowledge base scoped to the current user.
      # Returns 404 if not found or if it belongs to a different user.
      def set_knowledge_base
        @knowledge_base = current_user.knowledge_bases.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found("Knowledge base")
      end

      # Strong parameters for knowledge base creation/update.
      #
      # @return [ActionController::Parameters] permitted: +name+, +description+
      def knowledge_base_params
        params.permit(:name, :description)
      end
    end
  end
end
