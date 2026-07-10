# frozen_string_literal: true

# Performs semantic (vector similarity) search over a knowledge base's
# indexed document chunks using pgvector.
#
# This is the "retrieval" half of the RAG pipeline. Given a natural-language
# query, it:
# 1. Embeds the query text via {EmbeddingService}
# 2. Finds the nearest chunk vectors using pgvector's cosine distance
# 3. Filters by an optional minimum similarity threshold
# 4. Returns ranked {SearchResult} structs with document metadata
#
# All searches are scoped to a single {KnowledgeBase}. Results include
# the originating document title and chunk position for source attribution.
#
# @note Requires indexed documents — returns an error response (not an
#   exception) if the knowledge base has no indexed chunks.
# @note Search errors are returned inside {SearchResponse#error} rather
#   than raised, so callers can handle failures gracefully.
#
# @example Basic semantic search
#   service = SearchService.new(knowledge_base: kb)
#   response = service.search(query: "How does authentication work?")
#   if response.success?
#     response.results.each { |r| puts "#{r.rank}. #{r.document_title} (#{r.similarity_score})" }
#   end
#
# @example Search with similarity threshold
#   response = service.search(query: "JWT tokens", limit: 3, min_similarity: 0.5)
#
# @example Multi-query search (union of results)
#   results = service.multi_search(queries: ["auth", "login", "session"], limit: 10)
#
# @see RagService Uses SearchService to retrieve context for LLM generation
# @see EmbeddingService Generates query embeddings
class SearchService
  # @return [Integer] default number of results returned
  DEFAULT_LIMIT = 5

  # @return [Integer] absolute maximum results allowed per search
  MAX_LIMIT = 20

  # @return [Integer] minimum query string length
  MIN_QUERY_LENGTH = 2

  # @return [Integer] maximum query string length
  MAX_QUERY_LENGTH = 1000

  # Base error for search-related failures.
  class SearchError < StandardError; end

  # Raised when the query string fails validation (blank, too short, too long).
  class InvalidQueryError < SearchError; end

  # Raised when the query embedding cannot be generated.
  class EmbeddingGenerationError < SearchError; end

  # Raised when the knowledge base has no indexed documents.
  class NoIndexedDocumentsError < SearchError; end

  # A single search hit with chunk content, similarity score, and
  # document metadata.
  #
  # @!attribute [rw] rank
  #   @return [Integer] 1-based position in results
  # @!attribute [rw] chunk_id
  #   @return [Integer] database ID of the matched chunk
  # @!attribute [rw] content
  #   @return [String] the chunk's text content
  # @!attribute [rw] similarity_score
  #   @return [Float] cosine similarity (0.0–1.0)
  # @!attribute [rw] document_id
  #   @return [Integer] ID of the parent document
  # @!attribute [rw] document_title
  #   @return [String] title of the parent document
  # @!attribute [rw] chunk_index
  #   @return [Integer] position of this chunk within its document
  SearchResult = Struct.new(
    :rank,
    :chunk_id,
    :content,
    :similarity_score,
    :document_id,
    :document_title,
    :chunk_index,
    keyword_init: true
  )

  # Wraps a list of {SearchResult}s with query metadata and timing info.
  #
  # @!attribute [rw] results
  #   @return [Array<SearchResult>] ranked search hits
  # @!attribute [rw] query
  #   @return [String] the original query string
  # @!attribute [rw] total_chunks_searched
  #   @return [Integer] total indexed chunks in the knowledge base
  # @!attribute [rw] knowledge_base_id
  #   @return [Integer] scoped knowledge base ID
  # @!attribute [rw] search_time_ms
  #   @return [Float] elapsed search time in milliseconds
  # @!attribute [rw] error
  #   @return [String, nil] error message if the search failed
  SearchResponse = Struct.new(
    :results,
    :query,
    :total_chunks_searched,
    :knowledge_base_id,
    :search_time_ms,
    :error,
    keyword_init: true
  ) do
    # @return [Boolean] +true+ if no error occurred
    def success?
      error.nil?
    end

    # @return [Hash] serializable representation
    def to_h
      {
        results: results.map(&:to_h),
        query: query,
        total_chunks_searched: total_chunks_searched,
        knowledge_base_id: knowledge_base_id,
        search_time_ms: search_time_ms
      }.tap do |h|
        h[:error] = error if error.present?
      end
    end
  end

  # @param knowledge_base [KnowledgeBase] the knowledge base to search within
  # @param embedding_service [EmbeddingService, nil] service for generating
  #   query embeddings (default: new instance)
  # @param logger [Logger, nil] logger for search metrics (default: +Rails.logger+)
  def initialize(knowledge_base:, embedding_service: nil, logger: nil)
    @knowledge_base = knowledge_base
    @embedding_service = embedding_service || EmbeddingService.new
    @logger = logger || Rails.logger
  end

  # Perform a semantic search against the knowledge base.
  #
  # Embeds the query, finds the nearest chunk vectors via pgvector cosine
  # distance, and returns results above the optional similarity threshold.
  #
  # @param query [String] natural-language search query
  # @param limit [Integer] maximum number of results (default: {DEFAULT_LIMIT},
  #   max: {MAX_LIMIT})
  # @param min_similarity [Float, nil] discard results below this cosine
  #   similarity (0.0–1.0); nil means no threshold
  # @return [SearchResponse] results with metadata; check +.success?+ before
  #   using +.results+
  #
  # @example
  #   response = service.search(query: "deployment process", limit: 3)
  #   response.results.first.document_title # => "DevOps Guide"
  def search(query:, limit: DEFAULT_LIMIT, min_similarity: nil)
    start_time = Time.current

    validate_query!(query)
    limit = normalize_limit(limit)

    chunks_count = total_indexed_chunks
    if chunks_count.zero?
      return build_error_response(
        query: query,
        error: "No indexed documents in this knowledge base",
        search_time_ms: elapsed_ms(start_time)
      )
    end

    query_embedding = generate_query_embedding(query)

    chunks = find_similar_chunks(query_embedding, limit)

    results = build_results(chunks, min_similarity)

    log_search(query, results.length, elapsed_ms(start_time))

    SearchResponse.new(
      results: results,
      query: query,
      total_chunks_searched: chunks_count,
      knowledge_base_id: @knowledge_base.id,
      search_time_ms: elapsed_ms(start_time),
      error: nil
    )
  rescue InvalidQueryError => e
    build_error_response(query: query, error: e.message, search_time_ms: elapsed_ms(start_time))
  rescue EmbeddingGenerationError => e
    build_error_response(query: query, error: e.message, search_time_ms: elapsed_ms(start_time))
  rescue StandardError => e
    @logger.error("[SearchService] Unexpected error: #{e.message}")
    @logger.error(e.backtrace&.first(5)&.join("\n"))
    build_error_response(query: query, error: "Search failed: #{e.message}", search_time_ms: elapsed_ms(start_time))
  end

  # Search with multiple query strings and merge deduplicated results.
  #
  # Useful for broadening recall — e.g., searching with synonyms or
  # rephrased questions. Duplicate chunks (by ID) are removed, and the
  # combined results are re-sorted by similarity score.
  #
  # @param queries [Array<String>] list of search queries
  # @param limit [Integer] maximum total results returned
  # @return [Array<SearchResult>] deduplicated, similarity-sorted results
  #
  # @example
  #   service.multi_search(queries: ["authentication", "login flow"], limit: 5)
  def multi_search(queries:, limit: DEFAULT_LIMIT)
    all_results = []
    seen_chunk_ids = Set.new

    queries.each do |query|
      response = search(query: query, limit: limit)
      next unless response.success?

      response.results.each do |result|
        next if seen_chunk_ids.include?(result.chunk_id)

        seen_chunk_ids.add(result.chunk_id)
        all_results << result
      end
    end

    all_results.sort_by { |r| -r.similarity_score }.first(limit)
  end

  # Suggest document titles matching a prefix string.
  #
  # Performs a case-insensitive ILIKE search on indexed document titles.
  # Intended for autocomplete/typeahead UI features.
  #
  # @param prefix [String] the prefix to match against document titles
  # @param limit [Integer] maximum number of suggestions (default: 5)
  # @return [Array<String>] matching document titles
  #
  # @example
  #   service.suggest_queries(prefix: "deploy") # => ["Deployment Guide", "Deploy Scripts"]
  def suggest_queries(prefix:, limit: 5)
    return [] if prefix.blank? || prefix.length < 2

    @knowledge_base.documents
      .indexed
      .where("title ILIKE ?", "%#{prefix}%")
      .limit(limit)
      .pluck(:title)
  end

  private

  # Validate query length and presence.
  #
  # @param query [String]
  # @raise [InvalidQueryError] if validation fails
  def validate_query!(query)
    if query.blank?
      raise InvalidQueryError, "Query parameter is required"
    end

    if query.length < MIN_QUERY_LENGTH
      raise InvalidQueryError, "Query must be at least #{MIN_QUERY_LENGTH} characters"
    end

    if query.length > MAX_QUERY_LENGTH
      raise InvalidQueryError, "Query must not exceed #{MAX_QUERY_LENGTH} characters"
    end
  end

  # Clamp the limit to the valid range [1, MAX_LIMIT].
  #
  # @param limit [Integer, String] raw limit value
  # @return [Integer] normalized limit
  def normalize_limit(limit)
    limit = limit.to_i
    limit = DEFAULT_LIMIT if limit < 1
    [ limit, MAX_LIMIT ].min
  end

  # Embed the query text and validate the result.
  #
  # @param query [String] search query
  # @return [Array<Float>] query embedding vector
  # @raise [EmbeddingGenerationError] if embedding is nil or empty
  def generate_query_embedding(query)
    embedding = @embedding_service.generate(query)

    if embedding.nil? || embedding.empty?
      raise EmbeddingGenerationError, "Failed to generate query embedding"
    end

    embedding
  rescue EmbeddingService::EmbeddingError => e
    raise EmbeddingGenerationError, "Embedding generation failed: #{e.message}"
  end

  # Query pgvector for the nearest chunk embeddings using cosine distance.
  #
  # @param query_embedding [Array<Float>] the query vector
  # @param limit [Integer] max results
  # @return [ActiveRecord::Relation<Chunk>] chunks with +neighbor_distance+
  def find_similar_chunks(query_embedding, limit)
    Chunk.for_knowledge_base(@knowledge_base.id)
         .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
         .limit(limit)
         .includes(:document)
  end

  # Convert raw chunk records into {SearchResult} structs, applying
  # the optional similarity threshold and re-ranking after filtering.
  #
  # @param chunks [ActiveRecord::Relation<Chunk>] nearest-neighbor results
  # @param min_similarity [Float, nil] minimum similarity cutoff
  # @return [Array<SearchResult>] filtered and ranked results
  def build_results(chunks, min_similarity = nil)
    results = []

    chunks.each_with_index do |chunk, index|
      similarity = calculate_similarity(chunk)

      next if min_similarity && similarity < min_similarity

      results << SearchResult.new(
        rank: index + 1,
        chunk_id: chunk.id,
        content: chunk.content,
        similarity_score: similarity,
        document_id: chunk.document.id,
        document_title: chunk.document.title,
        chunk_index: chunk.chunk_index
      )
    end

    # Re-rank sequentially after threshold filtering may have removed entries
    results.each_with_index { |r, i| r.rank = i + 1 }

    results
  end

  # Convert pgvector's cosine distance to a similarity score.
  #
  # The neighbor gem returns cosine *distance* (0 = identical, 2 = opposite).
  # We convert to similarity: +1.0 - distance+, clamped to [0.0, 1.0].
  #
  # @param chunk [Chunk] chunk with +neighbor_distance+ attribute
  # @return [Float] similarity score rounded to 4 decimal places
  def calculate_similarity(chunk)
    distance = chunk.neighbor_distance rescue 0.0
    similarity = (1.0 - distance.to_f)

    similarity.clamp(0.0, 1.0).round(4)
  end

  # Count total indexed chunks for this knowledge base (memoized).
  #
  # @return [Integer]
  def total_indexed_chunks
    @total_indexed_chunks ||= Chunk.for_knowledge_base(@knowledge_base.id).count
  end

  # Build an error {SearchResponse} with no results.
  #
  # @param query [String]
  # @param error [String] error description
  # @param search_time_ms [Float]
  # @return [SearchResponse]
  def build_error_response(query:, error:, search_time_ms:)
    SearchResponse.new(
      results: [],
      query: query,
      total_chunks_searched: 0,
      knowledge_base_id: @knowledge_base.id,
      search_time_ms: search_time_ms,
      error: error
    )
  end

  # Calculate elapsed milliseconds since a start time.
  #
  # @param start_time [Time]
  # @return [Float] milliseconds, rounded to 2 decimal places
  def elapsed_ms(start_time)
    ((Time.current - start_time) * 1000).round(2)
  end

  # Log search metrics for observability.
  #
  # @param query [String]
  # @param results_count [Integer]
  # @param time_ms [Float]
  def log_search(query, results_count, time_ms)
    @logger.info(
      "[SearchService] KB #{@knowledge_base.id}: " \
      "query='#{query.truncate(50)}' results=#{results_count} time=#{time_ms}ms"
    )
  end
end
