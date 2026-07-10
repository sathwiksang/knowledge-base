# Serializes {KnowledgeBase} records into JSON for API responses.
#
# Used by {Api::V1::KnowledgeBasesController} for listing, showing,
# creating, and updating knowledge bases.
#
# == Available views
#
# | View            | Use case                                 | Extra fields                                              |
# |----------------|------------------------------------------|-----------------------------------------------------------|
# | (default)      | Create/update responses                  | +id+, +name+, +description+, +created_at+, +updated_at+       |
# | :with_stats    | Index/show (most common)                 | + +total_documents+, +indexed_documents+, +total_chunks+       |
# | :with_documents| Detailed KB view with nested documents   | + all stats + nested +documents+ array                      |
#
# == Default view — example
#
# Input:
#   kb = KnowledgeBase.find(1)  # name: "Engineering Docs"
#
# Output:
#   KnowledgeBaseBlueprint.render_as_hash(kb)
#   # => {
#   #      "id": 1,
#   #      "name": "Engineering Docs",
#   #      "description": "Internal engineering documentation",
#   #      "created_at": "2026-01-15T10:30:00.000Z",
#   #      "updated_at": "2026-02-01T14:00:00.000Z"
#   #    }
#
# == :with_stats view — example
#
# Output:
#   KnowledgeBaseBlueprint.render_as_hash(kb, view: :with_stats)
#   # => {
#   #      "id": 1,
#   #      "name": "Engineering Docs",
#   #      "description": "Internal engineering documentation",
#   #      "created_at": "2026-01-15T10:30:00.000Z",
#   #      "updated_at": "2026-02-01T14:00:00.000Z",
#   #      "total_documents": 12,
#   #      "indexed_documents": 10,
#   #      "total_chunks": 87
#   #    }
#
# == :with_documents view — example
#
# Output:
#   KnowledgeBaseBlueprint.render_as_hash(kb, view: :with_documents)
#   # => {
#   #      "id": 1,
#   #      "name": "Engineering Docs",
#   #      ...all stats fields...,
#   #      "documents": [
#   #        {
#   #          "id": 1,
#   #          "title": "Auth Guide",
#   #          "status": "indexed",
#   #          "content_preview": "This guide explains how authentication...",
#   #          "created_at": "2026-01-16T09:00:00.000Z",
#   #          "updated_at": "2026-01-16T09:05:00.000Z"
#   #        },
#   #        ...
#   #      ]
#   #    }
#
# @see KnowledgeBase The model being serialized
# @see Api::V1::KnowledgeBasesController Endpoints that use this blueprint
# @see DocumentBlueprint Nested serializer for :with_documents view
class KnowledgeBaseBlueprint < Blueprinter::Base
  # @!attribute [r] id
  #   Primary key of the knowledge base.
  identifier :id

  # @!attribute [r] name
  #   The knowledge base name (unique per user).
  # @!attribute [r] description
  #   Optional description of what the KB contains (may be +nil+).
  # @!attribute [r] created_at
  #   When the KB was created (ISO 8601).
  # @!attribute [r] updated_at
  #   When the KB was last modified (ISO 8601).
  fields :name, :description, :created_at, :updated_at

  # Adds document processing statistics. This is the most commonly used
  # view — the index and show endpoints both use it so the UI can
  # display how many documents are indexed and ready for search.
  view :with_stats do
    # @!attribute [r] total_documents
    #   Total number of documents in this KB (all statuses).
    field :total_documents do |kb|
      kb.total_documents
    end

    # @!attribute [r] indexed_documents
    #   Number of documents that have been fully processed and are
    #   searchable. If this is 0, the /search and /ask endpoints will
    #   return an error.
    field :indexed_documents do |kb|
      kb.indexed_documents
    end

    # @!attribute [r] total_chunks
    #   Total number of text chunks across all documents. Gives a
    #   sense of how much content is indexed (a typical document
    #   produces 5–20 chunks).
    field :total_chunks do |kb|
      kb.total_chunks
    end
  end

  # Full view with nested documents. Includes all stats plus the list
  # of documents serialized with the default {DocumentBlueprint} view.
  #
  # Use sparingly — for KBs with many documents this can produce a
  # large response. Prefer the documents index endpoint for paginated
  # access.
  view :with_documents do
    include_view :with_stats

    # Nested array of documents using the default DocumentBlueprint view.
    # Each document includes: id, title, status, content_preview, timestamps.
    association :documents, blueprint: DocumentBlueprint
  end
end
