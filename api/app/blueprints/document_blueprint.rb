# Serializes {Document} records into JSON for API responses.
#
# Used by {Api::V1::DocumentsController} and nested inside
# {KnowledgeBaseBlueprint} and {SearchResultBlueprint}.
#
# This blueprint has four views of increasing detail, from a minimal
# reference (just id + title) up to a full dump with nested chunks.
# Choose the smallest view that gives the client what it needs to
# avoid sending unnecessary data over the wire.
#
# == Available views
#
# | View          | Use case                                    | Key fields                                         |
# |--------------|---------------------------------------------|----------------------------------------------------|
# | (default)    | Document lists, create/update responses      | +id+, +title+, +status+, +content_preview+, timestamps |
# | :minimal     | Inline references (e.g. inside search results)| +id+, +title+ only                                  |
# | :detailed    | Single document show endpoint                | + +content+, +metadata+, +chunks_count+               |
# | :with_chunks | Debugging, full document dump                | + nested +chunks+ array                              |
#
# == Default view — example
#
# Input:
#   doc = Document.find(1)  # title: "Auth Guide", status: "indexed"
#
# Output:
#   DocumentBlueprint.render_as_hash(doc)
#   # => {
#   #      "id": 1,
#   #      "title": "Auth Guide",
#   #      "status": "indexed",
#   #      "content_preview": "This guide explains how JWT authentication works in our API. Tokens are...",
#   #      "created_at": "2026-01-16T09:00:00.000Z",
#   #      "updated_at": "2026-01-16T09:05:00.000Z"
#   #    }
#
# == :minimal view — example
#
# Output:
#   DocumentBlueprint.render_as_hash(doc, view: :minimal)
#   # => {
#   #      "id": 1,
#   #      "title": "Auth Guide"
#   #    }
#
# == :detailed view — example
#
# Output:
#   DocumentBlueprint.render_as_hash(doc, view: :detailed)
#   # => {
#   #      "id": 1,
#   #      "title": "Auth Guide",
#   #      "status": "indexed",
#   #      "content_preview": "This guide explains how JWT authentication...",
#   #      "created_at": "2026-01-16T09:00:00.000Z",
#   #      "updated_at": "2026-01-16T09:05:00.000Z",
#   #      "content": "This guide explains how JWT authentication works in our API. Tokens are issued on login...(full text)...",
#   #      "metadata": { "error": null },
#   #      "chunks_count": 8
#   #    }
#
# == :with_chunks view — example
#
# Output:
#   DocumentBlueprint.render_as_hash(doc, view: :with_chunks)
#   # => {
#   #      ...all detailed fields...,
#   #      "chunks": [
#   #        { "id": 10, "content": "This guide explains...", "chunk_index": 0, "created_at": "..." },
#   #        { "id": 11, "content": "Tokens are issued on...", "chunk_index": 1, "created_at": "..." }
#   #      ]
#   #    }
#
# @see Document The model being serialized
# @see Api::V1::DocumentsController Endpoints that use this blueprint
# @see ChunkBlueprint Nested serializer for :with_chunks view
class DocumentBlueprint < Blueprinter::Base
  # @!attribute [r] id
  #   Primary key of the document.
  identifier :id

  # @!attribute [r] title
  #   The document's human-readable title.
  # @!attribute [r] status
  #   Processing lifecycle state: "pending", "processing", "indexed", or "failed".
  # @!attribute [r] created_at
  #   When the document was uploaded (ISO 8601).
  # @!attribute [r] updated_at
  #   When the document was last modified (ISO 8601).
  fields :title, :status, :created_at, :updated_at

  # @!attribute [r] content_preview
  #   First 200 characters of the document content, truncated with "...".
  #   Gives the client a snippet without sending the full text. Included
  #   in the default view so document lists can show previews.
  field :content_preview do |doc|
    doc.content&.truncate(200)
  end

  # Smallest possible representation — just id and title.
  # Used as an inline reference inside {SearchResultBlueprint} where
  # only the document identity is needed (the search result itself
  # carries the chunk content and score).
  view :minimal do
    identifier :id
    # @!attribute [r] title
    field :title
  end

  # Full document content plus processing metadata.
  # Used by the single-document show endpoint (+GET /api/v1/documents/:id+)
  # where the user wants to read the entire document.
  view :detailed do
    # @!attribute [r] content
    #   The full document text. Can be very large — only request this
    #   view when you actually need the full content.
    field :content

    # @!attribute [r] metadata
    #   JSONB metadata hash. Contains +{"error": "..."}+ when the
    #   document failed processing, otherwise +{}+.
    field :metadata

    # @!attribute [r] chunks_count
    #   Number of text chunks created during processing. Zero for
    #   pending/failed documents, typically 5–20 for indexed ones.
    field :chunks_count do |doc|
      doc.chunks.count
    end
  end

  # Full document with nested chunk records. Includes everything from
  # :detailed plus the array of chunks.
  #
  # Use sparingly — a document with 20 chunks each containing ~500
  # characters produces a significant payload. Primarily useful for
  # debugging or building a "view chunks" admin UI.
  view :with_chunks do
    include_view :detailed

    # Nested array of chunks using the default {ChunkBlueprint} view.
    # Each chunk includes: id, content, chunk_index, created_at.
    # Embeddings are NOT included (they are 768-float arrays).
    association :chunks, blueprint: ChunkBlueprint
  end
end
