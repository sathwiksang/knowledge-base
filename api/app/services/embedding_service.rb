# frozen_string_literal: true

# Generates and validates vector embeddings for text using Ollama's nomic-embed-text model.
#
# This service converts text into 768-dimensional float vectors that capture
# semantic meaning. These vectors are stored via pgvector and used by
# {SearchService} to perform cosine-similarity searches across document chunks.
#
# @note Requires a running Ollama instance with the +nomic-embed-text+ model
#   pulled. Use {#available?} to verify connectivity before processing.
# @note Input text is normalized (whitespace collapsed, truncated to
#   {MAX_TEXT_LENGTH}) before being sent to the model.
#
# @example Generate an embedding for a single text
#   service = EmbeddingService.new
#   vector = service.generate("What is machine learning?")
#   vector.length # => 768
#
# @example Batch-generate embeddings
#   vectors = service.generate_batch(["text one", "text two"])
#   vectors.length # => 2
#
# @example Check if the embedding backend is reachable
#   service.available? # => true
#
# @see SearchService Used by SearchService to embed user queries
# @see DocumentProcessorService Used during document indexing
class EmbeddingService
  # @return [Integer] the number of dimensions produced by nomic-embed-text
  EMBEDDING_DIMENSIONS = 768

  # @return [Integer] maximum input characters (text is truncated beyond this)
  MAX_TEXT_LENGTH = 8000

  # @return [Integer] number of texts processed per batch iteration
  BATCH_SIZE = 10

  # Base error for all embedding-related failures.
  class EmbeddingError < StandardError; end

  # Raised when input text is invalid or contains non-numeric embedding values.
  class InvalidInputError < EmbeddingError; end

  # Raised when the returned embedding vector has an unexpected number of dimensions.
  class DimensionMismatchError < EmbeddingError; end

  # @param client [Clients::OllamaClient, nil] Ollama HTTP client instance;
  #   defaults to a new {Clients::OllamaClient} if not provided
  def initialize(client: nil)
    @client = client || Clients::OllamaClient.new
  end

  # Generate a single embedding vector for the given text.
  #
  # The text is normalized (whitespace collapsed, truncated to {MAX_TEXT_LENGTH})
  # before being sent to the embedding model. Returns +nil+ for blank input
  # rather than raising, so callers can safely pass optional text.
  #
  # @param text [String] the input text to embed
  # @return [Array<Float>, nil] 768-dimensional vector, or +nil+ if text is blank
  # @raise [EmbeddingError] if the Ollama API call fails
  # @raise [DimensionMismatchError] if the returned vector has wrong dimensions
  #
  # @example
  #   EmbeddingService.new.generate("Hello world")
  #   # => [0.0123, -0.0456, ..., 0.0789]  (768 floats)
  def generate(text)
    return nil if text.blank?

    normalized_text = normalize_text(text)
    return nil if normalized_text.blank?

    embedding = @client.embed(normalized_text)

    validate_embedding!(embedding)

    embedding
  rescue Clients::OllamaClient::OllamaError => e
    Rails.logger.error("Embedding generation failed: #{e.message}")
    raise EmbeddingError, "Failed to generate embedding: #{e.message}"
  end

  # Generate embeddings for multiple texts in batches.
  #
  # Processes texts in slices of {BATCH_SIZE} to avoid overwhelming the
  # Ollama server. Blank texts produce +nil+ entries in the result array.
  #
  # @param texts [Array<String>] list of texts to embed
  # @return [Array<Array<Float>, nil>] embeddings in the same order as input
  # @raise [EmbeddingError] if any individual embedding generation fails
  #
  # @example
  #   service.generate_batch(["first doc", "second doc"])
  #   # => [[0.01, ...], [0.02, ...]]
  def generate_batch(texts)
    return [] if texts.blank?

    texts.each_slice(BATCH_SIZE).flat_map do |batch|
      batch.map { |text| generate(text) }
    end
  end

  # Generate embeddings for multiple texts, keyed by their original index.
  #
  # Useful when you need to correlate embeddings back to a source array
  # by position rather than relying on array ordering.
  #
  # @param texts [Array<String>] list of texts to embed
  # @return [Hash{Integer => Array<Float>}] mapping of text index to embedding
  # @raise [EmbeddingError] if any individual embedding generation fails
  #
  # @example
  #   service.generate_batch_with_indices(["a", "b"])
  #   # => { 0 => [0.01, ...], 1 => [0.02, ...] }
  def generate_batch_with_indices(texts)
    return {} if texts.blank?

    embeddings = generate_batch(texts)

    texts.each_with_index.to_h do |_text, index|
      [ index, embeddings[index] ]
    end
  end

  # Calculate cosine similarity between two embedding vectors.
  #
  # Returns a value between 0.0 (orthogonal/unrelated) and 1.0 (identical).
  # Validates both vectors before computation.
  #
  # @param embedding1 [Array<Float>] first embedding vector
  # @param embedding2 [Array<Float>] second embedding vector
  # @return [Float] cosine similarity score (0.0–1.0)
  # @raise [DimensionMismatchError] if either vector has wrong dimensions
  #
  # @example
  #   sim = service.cosine_similarity(vec_a, vec_b)
  #   puts "#{(sim * 100).round(1)}% similar"
  def cosine_similarity(embedding1, embedding2)
    return 0.0 if embedding1.blank? || embedding2.blank?

    validate_embedding!(embedding1)
    validate_embedding!(embedding2)

    dot_product = embedding1.zip(embedding2).sum { |a, b| a * b }
    magnitude1 = Math.sqrt(embedding1.sum { |x| x**2 })
    magnitude2 = Math.sqrt(embedding2.sum { |x| x**2 })

    # Avoid division by zero for zero-magnitude vectors
    return 0.0 if magnitude1.zero? || magnitude2.zero?

    dot_product / (magnitude1 * magnitude2)
  end

  # Check whether the Ollama embedding service is reachable and the
  # configured model is available.
  #
  # @return [Boolean] +true+ if healthy and model is pulled
  def available?
    @client.health_check && @client.model_available?(embedding_model_name)
  end

  # Return the configured embedding model name from environment or default.
  #
  # @return [String] model name (e.g. +"nomic-embed-text"+)
  def embedding_model_name
    ENV.fetch("OLLAMA_EMBEDDING_MODEL", "nomic-embed-text")
  end

  # Return the expected embedding vector dimensionality.
  #
  # @return [Integer] number of dimensions (768)
  def dimensions
    EMBEDDING_DIMENSIONS
  end

  private

  # Normalize input text for consistent embedding generation.
  # Collapses whitespace, removes newlines, and enforces the max length.
  #
  # @param text [String] raw input text
  # @return [String] cleaned text ready for the embedding model
  def normalize_text(text)
    text.to_s
        .gsub(/\s+/, " ")           # Collapse all whitespace to single spaces
        .gsub(/[\r\n]+/, " ")       # Replace newlines with spaces
        .strip
        .truncate(MAX_TEXT_LENGTH, omission: "")  # Hard limit, no ellipsis
  end

  # Validate that an embedding has the correct structure and dimensions.
  #
  # @param embedding [Object] the value to validate
  # @return [true] if valid
  # @raise [DimensionMismatchError] if not an Array or wrong length
  # @raise [InvalidInputError] if contains non-numeric values
  def validate_embedding!(embedding)
    unless embedding.is_a?(Array)
      raise DimensionMismatchError, "Invalid embedding: expected Array, got #{embedding.class}"
    end

    unless embedding.length == EMBEDDING_DIMENSIONS
      raise DimensionMismatchError,
            "Invalid embedding dimensions: expected #{EMBEDDING_DIMENSIONS}, got #{embedding.length}"
    end

    unless embedding.all? { |v| v.is_a?(Numeric) }
      raise InvalidInputError, "Invalid embedding: contains non-numeric values"
    end

    true
  end
end
