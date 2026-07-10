# Serializes {Chunk} records into JSON for API responses.
#
# Chunks are segments of a {Document}'s text content paired with a
# vector embedding. This blueprint intentionally **excludes the
# embedding column** because it is a 768-float array (~6 KB of JSON
# per chunk) that is useless to API consumers.
#
# == Available views
#
# | View             | Use case                                  | Extra fields          |
# |-----------------|-------------------------------------------|-----------------------|
# | (default)       | Nested inside DocumentBlueprint :with_chunks | +id+, +content+, +chunk_index+, +created_at+ |
# | :with_similarity| Display chunks with search relevance scores | + +similarity_score+   |
#
# == Default view — example
#
# Input:
#   chunk = Chunk.find(10)  # content: "JWT tokens are issued on login...", chunk_index: 0
#
# Output:
#   ChunkBlueprint.render_as_hash(chunk)
#   # => {
#   #      "id": 10,
#   #      "content": "JWT tokens are issued on login and expire after 24 hours...",
#   #      "chunk_index": 0,
#   #      "created_at": "2026-01-16T09:05:00.000Z"
#   #    }
#
# == :with_similarity view — example
#
# This view expects a +similarity_scores+ hash in the options, mapping
# chunk IDs to their cosine similarity scores. Used when rendering
# chunks that came from a search result.
#
# Output:
#   scores = { 10 => 0.8723, 11 => 0.7654 }
#   ChunkBlueprint.render_as_hash(chunk, view: :with_similarity, similarity_scores: scores)
#   # => {
#   #      "id": 10,
#   #      "content": "JWT tokens are issued on login and expire after 24 hours...",
#   #      "chunk_index": 0,
#   #      "created_at": "2026-01-16T09:05:00.000Z",
#   #      "similarity_score": 0.8723
#   #    }
#
# @see Chunk The model being serialized
# @see DocumentBlueprint Uses this blueprint in its :with_chunks view
# @see SearchResultBlueprint Alternative serializer for search results
class ChunkBlueprint < Blueprinter::Base
  # @!attribute [r] id
  #   Primary key of the chunk.
  identifier :id

  # @!attribute [r] content
  #   The text content of this chunk (typically 200–500 characters).
  # @!attribute [r] chunk_index
  #   0-based position of this chunk within its parent document.
  #   Chunk 0 is the beginning of the document, chunk N is the end.
  # @!attribute [r] created_at
  #   When the chunk was created during processing (ISO 8601).
  fields :content, :chunk_index, :created_at

  # NOTE: The +embedding+ column is deliberately excluded. It is a
  # 768-dimensional float array that would add ~6 KB per chunk to the
  # JSON response with no benefit to API consumers. Embeddings are only
  # used internally by pgvector for similarity search.

  # Extended view that includes a cosine similarity score.
  # Used when displaying chunks that were returned by a search query,
  # so the UI can show how relevant each chunk is to the query.
  #
  # The score must be passed via the +similarity_scores+ option because
  # it is computed at query time, not stored on the chunk record.
  view :with_similarity do
    # @!attribute [r] similarity_score
    #   Cosine similarity between this chunk's embedding and the query
    #   embedding (0.0 = unrelated, 1.0 = identical). Only present
    #   when the +:similarity_scores+ option is provided.
    field :similarity_score do |chunk, options|
      options[:similarity_scores]&.dig(chunk.id)
    end
  end
end
