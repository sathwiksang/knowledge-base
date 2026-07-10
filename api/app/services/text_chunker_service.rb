# frozen_string_literal: true

# Splits long-form text into overlapping chunks suitable for embedding and
# semantic search.
#
# Chunking is a critical step in the RAG pipeline: documents are too long
# to embed as a single vector, so they must be broken into smaller pieces
# that preserve semantic coherence. This service splits text at sentence
# and paragraph boundaries (rather than arbitrary character offsets) to
# keep each chunk meaningful.
#
# Consecutive chunks share an overlap region so that information spanning
# a chunk boundary is not lost during retrieval.
#
# @note Used by {DocumentProcessorService} during document indexing.
# @note Chunk size and overlap are configurable but must satisfy:
#   +MIN_CHUNK_SIZE <= chunk_size <= MAX_CHUNK_SIZE+ and +0 <= overlap < chunk_size+.
#
# @example Basic chunking with defaults
#   chunker = TextChunkerService.new
#   chunks  = chunker.chunk(long_article_text)
#   chunks.first
#   # => { content: "First chunk...", index: 0, char_start: 0, char_end: 498 }
#
# @example Custom chunk size for shorter documents
#   chunker = TextChunkerService.new(chunk_size: 200, overlap: 50)
#   chunks  = chunker.chunk(short_text)
#
# @example Estimating chunk count before processing
#   chunker = TextChunkerService.new
#   chunker.estimate_chunks(text) # => 12
#
# @see DocumentProcessorService Orchestrates chunking + embedding
class TextChunkerService
  # @return [Integer] default target characters per chunk
  DEFAULT_CHUNK_SIZE = 500

  # @return [Integer] default character overlap between consecutive chunks
  DEFAULT_OVERLAP = 100

  # @return [Integer] chunks shorter than this are discarded or merged
  MIN_CHUNK_SIZE = 50

  # @return [Integer] absolute upper bound for chunk size configuration
  MAX_CHUNK_SIZE = 2000

  # @return [Regexp] pattern matching sentence-ending punctuation followed by whitespace
  SENTENCE_ENDINGS = /(?<=[.!?])\s+/

  # @return [Regexp] pattern matching paragraph breaks (two or more newlines)
  PARAGRAPH_BREAK = /\n\n+/

  # Base error for chunking failures.
  class ChunkerError < StandardError; end

  # Raised when chunk_size or overlap parameters are out of valid range.
  class InvalidConfigError < ChunkerError; end

  # Create a new chunker with the given chunk size and overlap.
  #
  # @param chunk_size [Integer] target number of characters per chunk
  #   (default: {DEFAULT_CHUNK_SIZE})
  # @param overlap [Integer] number of characters shared between consecutive
  #   chunks (default: {DEFAULT_OVERLAP})
  # @raise [InvalidConfigError] if chunk_size or overlap are out of valid range
  #
  # @example
  #   TextChunkerService.new(chunk_size: 300, overlap: 75)
  def initialize(chunk_size: DEFAULT_CHUNK_SIZE, overlap: DEFAULT_OVERLAP)
    validate_config!(chunk_size, overlap)

    @chunk_size = chunk_size
    @overlap = overlap
  end

  # Split text into overlapping chunks at sentence/paragraph boundaries.
  #
  # The algorithm:
  # 1. Normalize whitespace and line endings
  # 2. Split into paragraphs, then sentences
  # 3. Accumulate sentences until +@chunk_size+ is reached
  # 4. Emit a chunk and carry over +@overlap+ characters worth of trailing
  #    sentences into the next chunk
  # 5. Discard any chunk shorter than {MIN_CHUNK_SIZE}
  #
  # @param text [String] the full document text to chunk
  # @return [Array<Hash>] chunks, each with keys +:content+, +:index+,
  #   +:char_start+, +:char_end+
  # @raise [ChunkerError] if an unexpected error occurs during chunking
  #
  # @example
  #   chunks = TextChunkerService.new.chunk("Long document text...")
  #   chunks.first[:content] # => "Long document text..."
  #   chunks.first[:index]   # => 0
  def chunk(text)
    return [] if text.blank?

    normalized = normalize_text(text)
    return [] if normalized.blank?

    paragraphs = split_into_paragraphs(normalized)

    chunks = build_chunks(paragraphs)

    chunks.select { |chunk| chunk[:content].length >= MIN_CHUNK_SIZE }
  end

  # Split text into chunks and attach arbitrary metadata to each one.
  #
  # Delegates to {#chunk} and merges the provided metadata hash plus
  # positional info (+chunk_index+, +total_chunks+) into each result.
  #
  # @param text [String] the document text to chunk
  # @param metadata [Hash] arbitrary metadata to attach to every chunk
  # @return [Array<Hash>] chunks with an additional +:metadata+ key
  #
  # @example
  #   chunker.chunk_with_metadata(text, source: "upload")
  #   # => [{ content: "...", index: 0, metadata: { source: "upload", chunk_index: 0, total_chunks: 5 } }, ...]
  def chunk_with_metadata(text, metadata = {})
    chunks = chunk(text)

    chunks.map do |chunk|
      chunk.merge(metadata: metadata.merge(
        chunk_index: chunk[:index],
        total_chunks: chunks.length
      ))
    end
  end

  # Chunk multiple document texts and track which document each chunk
  # originated from.
  #
  # @param documents [Array<String>] list of document texts
  # @return [Array<Hash>] chunks with an additional +:document_index+ key
  #
  # @example
  #   chunker.chunk_documents(["Doc one text...", "Doc two text..."])
  #   # => [{ content: "...", document_index: 0, ... }, ...]
  def chunk_documents(documents)
    documents.each_with_index.flat_map do |doc, doc_index|
      chunks = chunk(doc)
      chunks.map do |chunk|
        chunk.merge(document_index: doc_index)
      end
    end
  end

  # Calculate an optimal chunk size to produce approximately +target_chunks+
  # chunks for a given text length.
  #
  # @param text_length [Integer] total character count of the text
  # @param target_chunks [Integer] desired number of output chunks (default: 10)
  # @return [Integer] recommended chunk size, clamped to valid range
  #
  # @example
  #   TextChunkerService.optimal_chunk_size(5000, target_chunks: 10) # => 500
  def self.optimal_chunk_size(text_length, target_chunks: 10)
    return DEFAULT_CHUNK_SIZE if text_length <= 0

    optimal = (text_length / target_chunks.to_f).ceil
    optimal.clamp(MIN_CHUNK_SIZE, MAX_CHUNK_SIZE)
  end

  # Estimate how many chunks a text will produce without actually chunking it.
  #
  # This is a fast approximation based on character count and does not
  # account for sentence-boundary alignment, so actual counts may differ.
  #
  # @param text [String] the text to estimate for
  # @return [Integer] estimated number of chunks (0 if blank)
  #
  # @example
  #   TextChunkerService.new.estimate_chunks(long_text) # => 12
  def estimate_chunks(text)
    return 0 if text.blank?

    text_length = text.length
    return 1 if text_length <= @chunk_size

    # Effective step size is chunk_size minus overlap
    effective_chunk_size = @chunk_size - @overlap
    ((text_length - @overlap) / effective_chunk_size.to_f).ceil
  end

  private

  # Validate that chunk_size and overlap are within acceptable bounds.
  #
  # @param chunk_size [Integer]
  # @param overlap [Integer]
  # @raise [InvalidConfigError] if any constraint is violated
  def validate_config!(chunk_size, overlap)
    if chunk_size < MIN_CHUNK_SIZE
      raise InvalidConfigError, "Chunk size must be at least #{MIN_CHUNK_SIZE} characters"
    end

    if chunk_size > MAX_CHUNK_SIZE
      raise InvalidConfigError, "Chunk size must not exceed #{MAX_CHUNK_SIZE} characters"
    end

    if overlap >= chunk_size
      raise InvalidConfigError, "Overlap must be less than chunk size"
    end

    if overlap.negative?
      raise InvalidConfigError, "Overlap must be non-negative"
    end
  end

  # Normalize whitespace and line endings for consistent splitting.
  #
  # @param text [String] raw text
  # @return [String] cleaned text
  def normalize_text(text)
    text.to_s
        .gsub(/\r\n?/, "\n")        # Normalize line endings
        .gsub(/\n{3,}/, "\n\n")     # Collapse multiple newlines to double
        .gsub(/[ \t]+/, " ")        # Collapse horizontal whitespace
        .gsub(/^ +| +$/, "")        # Trim leading/trailing spaces from lines
        .strip
  end

  # Split text on double-newlines into paragraph strings.
  #
  # @param text [String] normalized text
  # @return [Array<String>] non-empty paragraph strings
  def split_into_paragraphs(text)
    text.split(PARAGRAPH_BREAK)
        .map(&:strip)
        .reject(&:empty?)
  end

  # Split a paragraph into individual sentences using punctuation boundaries.
  #
  # @param text [String] a single paragraph
  # @return [Array<String>] sentence strings
  def split_into_sentences(text)
    text.split(SENTENCE_ENDINGS)
        .map(&:strip)
        .reject(&:empty?)
  end

  # Core chunking algorithm: accumulate sentences into chunks with overlap.
  #
  # @param paragraphs [Array<String>] paragraph strings to process
  # @return [Array<Hash>] raw chunks (before min-size filtering)
  def build_chunks(paragraphs)
    chunks = []
    current_content = []
    current_length = 0
    char_position = 0

    paragraphs.each do |paragraph|
      sentences = split_into_sentences(paragraph)

      sentences.each do |sentence|
        sentence_length = sentence.length

        if current_length + sentence_length > @chunk_size && current_content.any?
          chunk_content = current_content.join(" ")
          chunks << {
            content: chunk_content,
            index: chunks.length,
            char_start: char_position - current_length,
            char_end: char_position
          }

          # Carry trailing sentences into the next chunk to maintain overlap
          overlap_content = get_overlap_content(current_content)
          current_content = overlap_content
          current_length = overlap_content.join(" ").length
        end

        current_content << sentence
        current_length += sentence_length + 1 # +1 for joining space
        char_position += sentence_length + 1
      end

      char_position += 1
    end

    # Flush remaining content as the final chunk
    if current_content.any?
      final_content = current_content.join(" ")
      if final_content.length >= MIN_CHUNK_SIZE
        chunks << {
          content: final_content,
          index: chunks.length,
          char_start: char_position - current_length,
          char_end: char_position
        }
      elsif chunks.any?
        # Merge into previous chunk to avoid discarding trailing content
        last_chunk = chunks.last
        last_chunk[:content] = "#{last_chunk[:content]} #{final_content}".strip
        last_chunk[:char_end] = char_position
      end
    end

    chunks
  end

  # Extract trailing sentences from the current chunk to seed the next chunk's
  # overlap region.
  #
  # @param sentences [Array<String>] sentences in the current chunk
  # @return [Array<String>] sentences whose combined length approximates +@overlap+
  def get_overlap_content(sentences)
    return [] if sentences.empty? || @overlap.zero?

    overlap_sentences = []
    total_length = 0

    # Walk backwards through sentences until we've accumulated enough overlap
    sentences.reverse_each do |sentence|
      break if total_length >= @overlap

      overlap_sentences.unshift(sentence)
      total_length += sentence.length + 1
    end

    overlap_sentences
  end
end
