# frozen_string_literal: true

# Implements the full Retrieval-Augmented Generation (RAG) pipeline:
# retrieve relevant context from indexed documents, then generate an
# LLM answer grounded in that context.
#
# This service ties together {SearchService} (retrieval) and {LlmService}
# (generation) to answer user questions against a specific {KnowledgeBase}.
# It also produces {SourceCitation}s so the API can show which documents
# informed each answer.
#
# The pipeline:
# 1. **Validate** the question (length, presence)
# 2. **Retrieve** the top-N most similar chunks via {SearchService}
# 3. **Build context** by concatenating chunk text (respecting
#    {MAX_CONTEXT_LENGTH})
# 4. **Generate** an answer via {LlmService} using the RAG system prompt
# 5. **Return** a {RagResponse} with the answer, sources, and timing
#
# @note Errors are captured into {RagResponse#error} rather than raised,
#   except for truly unexpected failures. This lets the API controller
#   return structured error responses.
# @note Supports multi-turn conversations via {#ask_with_history}.
#
# @example Ask a single question
#   rag = RagService.new(knowledge_base: kb)
#   response = rag.ask(question: "How do I deploy?")
#   if response.success?
#     puts response.answer
#     response.sources.each { |s| puts "  - #{s.document_title}" }
#   end
#
# @example Follow-up question with conversation history
#   response = rag.ask_with_history(
#     question: "Can you elaborate on step 3?",
#     history: [{ question: "How do I deploy?", answer: "First..." }]
#   )
#
# @example Check RAG availability
#   rag.available? # => true (Ollama is running)
#
# @see SearchService Retrieval component
# @see LlmService Generation component
# @see Api::V1::QuestionsController API endpoint that uses this service
class RagService
  # @return [Integer] default number of context chunks to retrieve
  DEFAULT_CONTEXT_CHUNKS = 5

  # @return [Integer] absolute maximum context chunks allowed
  MAX_CONTEXT_CHUNKS = 10

  # @return [Float] default minimum cosine similarity for retrieved chunks
  MIN_SIMILARITY_THRESHOLD = 0.3

  # @return [Integer] maximum total characters of context sent to the LLM
  MAX_CONTEXT_LENGTH = 4000

  # Base error for RAG-related failures.
  class RagError < StandardError; end

  # Raised when retrieved context is insufficient to answer the question.
  class InsufficientContextError < RagError; end

  # Raised when LLM generation fails.
  class GenerationError < RagError; end

  # Represents a single source document referenced in the answer.
  # Included in the API response for transparency and attribution.
  #
  # @!attribute [rw] document_id
  #   @return [Integer] ID of the source document
  # @!attribute [rw] document_title
  #   @return [String] title of the source document
  # @!attribute [rw] chunk_id
  #   @return [Integer] ID of the matched chunk
  # @!attribute [rw] chunk_index
  #   @return [Integer] position of the chunk within the document
  # @!attribute [rw] content_preview
  #   @return [String] truncated preview of the chunk content
  # @!attribute [rw] similarity_score
  #   @return [Float] cosine similarity to the query (0.0–1.0)
  SourceCitation = Struct.new(
    :document_id,
    :document_title,
    :chunk_id,
    :chunk_index,
    :content_preview,
    :similarity_score,
    keyword_init: true
  ) do
    # @return [Hash] serializable representation
    def to_h
      {
        document_id: document_id,
        document_title: document_title,
        chunk_id: chunk_id,
        chunk_index: chunk_index,
        content_preview: content_preview,
        similarity_score: similarity_score
      }
    end
  end

  # Complete response from the RAG pipeline, including the generated answer,
  # source citations, and performance metrics.
  #
  # @!attribute [rw] answer
  #   @return [String, nil] the generated answer, or nil on error
  # @!attribute [rw] question
  #   @return [String] the original question
  # @!attribute [rw] sources
  #   @return [Array<SourceCitation>] documents used to generate the answer
  # @!attribute [rw] knowledge_base_id
  #   @return [Integer] ID of the queried knowledge base
  # @!attribute [rw] model
  #   @return [String, nil] LLM model name used
  # @!attribute [rw] chunks_used
  #   @return [Integer] number of chunks included in context
  # @!attribute [rw] total_chunks_searched
  #   @return [Integer] total indexed chunks in the knowledge base
  # @!attribute [rw] processing_time_ms
  #   @return [Float] total pipeline time in milliseconds
  # @!attribute [rw] error
  #   @return [String, nil] error message if pipeline failed
  RagResponse = Struct.new(
    :answer,
    :question,
    :sources,
    :knowledge_base_id,
    :model,
    :chunks_used,
    :total_chunks_searched,
    :processing_time_ms,
    :error,
    keyword_init: true
  ) do
    # @return [Boolean] +true+ if no error occurred
    def success?
      error.nil?
    end

    # @return [Hash] serializable representation
    def to_h
      base = {
        answer: answer,
        question: question,
        sources: sources&.map(&:to_h) || [],
        knowledge_base_id: knowledge_base_id,
        model: model,
        chunks_used: chunks_used,
        total_chunks_searched: total_chunks_searched,
        processing_time_ms: processing_time_ms
      }

      base[:error] = error if error.present?
      base
    end
  end

  # @param knowledge_base [KnowledgeBase] the knowledge base to query
  # @param search_service [SearchService, nil] retrieval service
  #   (default: new instance scoped to the knowledge base)
  # @param llm_service [LlmService, nil] generation service
  #   (default: new instance)
  # @param logger [Logger, nil] logger (default: +Rails.logger+)
  def initialize(knowledge_base:, search_service: nil, llm_service: nil, logger: nil)
    @knowledge_base = knowledge_base
    @search_service = search_service || SearchService.new(knowledge_base: knowledge_base)
    @llm_service = llm_service || LlmService.new
    @logger = logger || Rails.logger
  end

  # Answer a question using retrieval-augmented generation.
  #
  # This is the primary entry point for single-turn Q&A. It retrieves
  # relevant chunks, builds a context string, and generates an answer
  # via the LLM.
  #
  # @param question [String] the user's natural-language question
  #   (3–1000 characters)
  # @param num_chunks [Integer] number of context chunks to retrieve
  #   (default: {DEFAULT_CONTEXT_CHUNKS}, max: {MAX_CONTEXT_CHUNKS})
  # @param min_similarity [Float, nil] minimum cosine similarity threshold;
  #   defaults to {MIN_SIMILARITY_THRESHOLD}
  # @param include_sources [Boolean] whether to include {SourceCitation}s
  #   in the response (default: +true+)
  # @return [RagResponse] the answer with metadata; check +.success?+ first
  #
  # @example
  #   response = rag.ask(question: "What is our refund policy?", num_chunks: 3)
  #   response.answer # => "According to the policy document..."
  def ask(question:, num_chunks: DEFAULT_CONTEXT_CHUNKS, min_similarity: nil, include_sources: true)
    start_time = Time.current

    validation_error = validate_question(question)
    return build_error_response(question, validation_error, start_time) if validation_error

    num_chunks = normalize_num_chunks(num_chunks)
    min_similarity ||= MIN_SIMILARITY_THRESHOLD

    # Step 1: Retrieve relevant context using semantic search
    search_response = retrieve_context(question, num_chunks, min_similarity)

    unless search_response.success?
      return build_error_response(
        question,
        "Search failed: #{search_response.error}",
        start_time,
        total_chunks_searched: search_response.total_chunks_searched
      )
    end

    # Step 2: Check if we have enough relevant context
    if search_response.results.empty?
      return build_error_response(
        question,
        "No relevant information found in the knowledge base for this question",
        start_time,
        total_chunks_searched: search_response.total_chunks_searched
      )
    end

    # Step 3: Build context from retrieved chunks
    context = build_context(search_response.results)
    sources = build_sources(search_response.results) if include_sources

    # Step 4: Generate answer using LLM
    llm_response = generate_answer(question, context)

    log_rag_request(question, search_response.results.length, elapsed_ms(start_time))

    RagResponse.new(
      answer: llm_response[:answer],
      question: question,
      sources: sources || [],
      knowledge_base_id: @knowledge_base.id,
      model: llm_response[:model],
      chunks_used: search_response.results.length,
      total_chunks_searched: search_response.total_chunks_searched,
      processing_time_ms: elapsed_ms(start_time),
      error: nil
    )
  rescue LlmService::LlmError => e
    @logger.error("[RagService] LLM error: #{e.message}")
    build_error_response(question, "Failed to generate answer: #{e.message}", start_time)
  rescue StandardError => e
    @logger.error("[RagService] Unexpected error: #{e.message}")
    @logger.error(e.backtrace&.first(5)&.join("\n"))
    build_error_response(question, "An unexpected error occurred: #{e.message}", start_time)
  end

  # Answer a question with multi-turn conversation history.
  #
  # Uses the chat endpoint of {LlmService} to maintain conversational
  # context. Previous Q&A pairs are prepended as message history so the
  # LLM can reference earlier answers.
  #
  # @param question [String] the current question (3–1000 characters)
  # @param history [Array<Hash>] previous exchanges, each with
  #   +:question+ and +:answer+ keys
  # @param num_chunks [Integer] number of context chunks to retrieve
  # @return [RagResponse] the answer with metadata
  #
  # @example
  #   response = rag.ask_with_history(
  #     question: "What about the second point?",
  #     history: [
  #       { question: "List the key features", answer: "1. Speed 2. Safety 3. ..." }
  #     ]
  #   )
  def ask_with_history(question:, history: [], num_chunks: DEFAULT_CONTEXT_CHUNKS)
    start_time = Time.current

    validation_error = validate_question(question)
    return build_error_response(question, validation_error, start_time) if validation_error

    num_chunks = normalize_num_chunks(num_chunks)

    search_response = retrieve_context(question, num_chunks)

    unless search_response.success? && search_response.results.any?
      return build_error_response(
        question,
        search_response.error || "No relevant context found",
        start_time,
        total_chunks_searched: search_response.total_chunks_searched
      )
    end

    context = build_context(search_response.results)
    messages = build_chat_messages(history, question, context)

    llm_response = @llm_service.chat(
      messages: messages,
      system_prompt: LlmService::RAG_SYSTEM_PROMPT
    )

    RagResponse.new(
      answer: llm_response[:response],
      question: question,
      sources: build_sources(search_response.results),
      knowledge_base_id: @knowledge_base.id,
      model: llm_response[:model],
      chunks_used: search_response.results.length,
      total_chunks_searched: search_response.total_chunks_searched,
      processing_time_ms: elapsed_ms(start_time),
      error: nil
    )
  rescue LlmService::LlmError => e
    build_error_response(question, "Failed to generate answer: #{e.message}", start_time)
  end

  # Check whether the RAG pipeline is operational.
  #
  # Verifies that the LLM service (Ollama) is reachable. Search
  # availability is implicitly checked when a question is asked.
  #
  # @return [Boolean] +true+ if the LLM is available
  def available?
    @llm_service.available?
  end

  private

  # Validate question presence and length constraints.
  #
  # @param question [String]
  # @return [String, nil] error message, or nil if valid
  def validate_question(question)
    return "Question is required" if question.blank?
    return "Question must be at least 3 characters" if question.length < 3
    return "Question must not exceed 1000 characters" if question.length > 1000

    nil
  end

  # Clamp num_chunks to the valid range [1, MAX_CONTEXT_CHUNKS].
  #
  # @param num_chunks [Integer, String]
  # @return [Integer]
  def normalize_num_chunks(num_chunks)
    num_chunks = num_chunks.to_i
    num_chunks = DEFAULT_CONTEXT_CHUNKS if num_chunks < 1
    [ num_chunks, MAX_CONTEXT_CHUNKS ].min
  end

  # Delegate semantic search to the search service.
  #
  # @param question [String]
  # @param num_chunks [Integer]
  # @param min_similarity [Float, nil]
  # @return [SearchService::SearchResponse]
  def retrieve_context(question, num_chunks, min_similarity = nil)
    @search_service.search(
      query: question,
      limit: num_chunks,
      min_similarity: min_similarity
    )
  end

  # Concatenate retrieved chunk content into a single context string,
  # respecting {MAX_CONTEXT_LENGTH} to avoid exceeding the LLM's
  # effective context window.
  #
  # @param results [Array<SearchService::SearchResult>]
  # @return [String] formatted context with source headers
  def build_context(results)
    context_parts = []
    total_length = 0

    results.each_with_index do |result, index|
      source_header = "[Source #{index + 1}: #{result.document_title}]"
      chunk_content = result.content.strip

      part = "#{source_header}\n#{chunk_content}"
      part_length = part.length

      # Stop adding chunks once we'd exceed the LLM context budget
      break if total_length + part_length > MAX_CONTEXT_LENGTH

      context_parts << part
      total_length += part_length + 2 # +2 for "\n\n" separator
    end

    context_parts.join("\n\n")
  end

  # Convert search results into {SourceCitation} structs for the API response.
  #
  # @param results [Array<SearchService::SearchResult>]
  # @return [Array<SourceCitation>]
  def build_sources(results)
    results.map do |result|
      SourceCitation.new(
        document_id: result.document_id,
        document_title: result.document_title,
        chunk_id: result.chunk_id,
        chunk_index: result.chunk_index,
        content_preview: result.content.truncate(150),
        similarity_score: result.similarity_score
      )
    end
  end

  # Generate an answer from the LLM using the built context.
  #
  # @param question [String]
  # @param context [String]
  # @return [Hash] with +:answer+ and +:model+ keys
  def generate_answer(question, context)
    @llm_service.answer_question(question: question, context: context)
  end

  # Build a chat message array from conversation history and current question.
  #
  # @param history [Array<Hash>] previous Q&A pairs
  # @param current_question [String]
  # @param context [String] retrieved context for the current question
  # @return [Array<Hash>] messages for the LLM chat endpoint
  def build_chat_messages(history, current_question, context)
    messages = []

    history.each do |entry|
      messages << { role: "user", content: entry[:question] }
      messages << { role: "assistant", content: entry[:answer] }
    end

    messages << {
      role: "user",
      content: build_contextual_question(current_question, context)
    }

    messages
  end

  # Format the current question with its retrieved context for the chat prompt.
  #
  # @param question [String]
  # @param context [String]
  # @return [String]
  def build_contextual_question(question, context)
    <<~PROMPT
      Context from knowledge base:
      ---
      #{context}
      ---

      Question: #{question}
    PROMPT
  end

  # Build an error {RagResponse} with no answer.
  #
  # @param question [String]
  # @param error [String] error description
  # @param start_time [Time]
  # @param total_chunks_searched [Integer]
  # @return [RagResponse]
  def build_error_response(question, error, start_time, total_chunks_searched: 0)
    RagResponse.new(
      answer: nil,
      question: question,
      sources: [],
      knowledge_base_id: @knowledge_base.id,
      model: nil,
      chunks_used: 0,
      total_chunks_searched: total_chunks_searched,
      processing_time_ms: elapsed_ms(start_time),
      error: error
    )
  end

  # Calculate elapsed milliseconds since a start time.
  #
  # @param start_time [Time]
  # @return [Float]
  def elapsed_ms(start_time)
    ((Time.current - start_time) * 1000).round(2)
  end

  # Log RAG request metrics for observability.
  #
  # @param question [String]
  # @param chunks_used [Integer]
  # @param time_ms [Float]
  def log_rag_request(question, chunks_used, time_ms)
    @logger.info(
      "[RagService] KB #{@knowledge_base.id}: " \
      "question='#{question.truncate(50)}' chunks=#{chunks_used} time=#{time_ms}ms"
    )
  end
end
