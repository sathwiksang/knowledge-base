# frozen_string_literal: true

# Serializes {SearchService::SearchResult} structs into JSON for API
# responses from the search endpoint.
#
# Unlike the other blueprints which serialize ActiveRecord models, this
# one serializes a plain Ruby Struct ({SearchService::SearchResult}).
# This is because search results are computed at query time — they
# combine data from both the {Chunk} and its parent {Document}, plus
# the similarity score calculated by pgvector.
#
# == Available views
#
# | View       | Use case                       | Extra fields                               |
# |-----------|--------------------------------|--------------------------------------------|
# | (default) | Search endpoint responses       | +chunk_id+, +rank+, +content+, +similarity_score+, +chunk_index+, nested +document+ |
# | :detailed | Debugging, admin tools          | + flat +document_id+, +document_title+      |
#
# == Default view — example
#
# Input:
#   result = SearchService::SearchResult.new(
#     rank: 1,
#     chunk_id: 42,
#     content: "JWT tokens are issued on login and expire after 24 hours...",
#     similarity_score: 0.8723,
#     document_id: 5,
#     document_title: "Auth Guide",
#     chunk_index: 3
#   )
#
# Output:
#   SearchResultBlueprint.render_as_hash(result)
#   # => {
#   #      "chunk_id": 42,
#   #      "rank": 1,
#   #      "content": "JWT tokens are issued on login and expire after 24 hours...",
#   #      "similarity_score": 0.8723,
#   #      "chunk_index": 3,
#   #      "document": {
#   #        "id": 5,
#   #        "title": "Auth Guide"
#   #      }
#   #    }
#
# == :detailed view — example
#
# Output:
#   SearchResultBlueprint.render_as_hash(result, view: :detailed)
#   # => {
#   #      "chunk_id": 42,
#   #      "rank": 1,
#   #      "content": "JWT tokens are issued on login and expire after 24 hours...",
#   #      "similarity_score": 0.8723,
#   #      "chunk_index": 3,
#   #      "document": {
#   #        "id": 5,
#   #        "title": "Auth Guide"
#   #      },
#   #      "document_id": 5,
#   #      "document_title": "Auth Guide"
#   #    }
#
# @see SearchService::SearchResult The struct being serialized
# @see Api::V1::KnowledgeBasesController#search Endpoint that uses this
# @see DocumentBlueprint :minimal view used for the nested document
class SearchResultBlueprint < Blueprinter::Base
  # @!attribute [r] chunk_id
  #   The database ID of the matched chunk. Used as the identifier
  #   instead of +id+ because SearchResult is a Struct, not an
  #   ActiveRecord model.
  identifier :chunk_id

  # @!attribute [r] rank
  #   1-based position in the result list (1 = most relevant).
  field :rank

  # @!attribute [r] content
  #   The full text of the matched chunk.
  field :content

  # @!attribute [r] similarity_score
  #   Cosine similarity between the query and this chunk (0.0–1.0).
  #   Higher = more relevant. Typically, scores above 0.7 are strong
  #   matches, and below 0.3 are weak.
  field :similarity_score

  # @!attribute [r] chunk_index
  #   Position of this chunk within its parent document (0-based).
  #   Lets the client show "from chunk 3 of Auth Guide".
  field :chunk_index

  # Default view includes a nested document reference serialized with
  # {DocumentBlueprint} :minimal view (just id + title).
  view :default do
    # @!attribute [r] document
    #   Nested object with the parent document's +id+ and +title+.
    #   Built from the flat +document_id+ and +document_title+ fields
    #   on the SearchResult struct using an OpenStruct adapter.
    association :document, blueprint: DocumentBlueprint, view: :minimal do |result, _options|
      # SearchResult is a Struct, not an AR model, so we can't use a
      # real association. Instead, we build a minimal object that
      # DocumentBlueprint :minimal can serialize (it only needs id + title).
      if result.respond_to?(:document_id)
        OpenStruct.new(
          id: result.document_id,
          title: result.document_title
        )
      else
        # Fallback for hash-style access (e.g. in tests)
        OpenStruct.new(
          id: result[:document_id],
          title: result[:document_title]
        )
      end
    end
  end

  # Extended view that adds flat document fields alongside the nested
  # document object. Useful for clients that prefer flat access
  # (+result.document_id+) over nested (+result.document.id+).
  view :detailed do
    include_view :default

    # @!attribute [r] document_id
    #   The parent document's database ID (flat field).
    field :document_id

    # @!attribute [r] document_title
    #   The parent document's title (flat field).
    field :document_title
  end
end
