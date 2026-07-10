# A named collection of documents that can be searched and queried
# together using semantic search and RAG.
#
# Knowledge bases are the main organisational unit. Each belongs to a
# single {User} and contains many {Document}s. When a document is
# indexed, its {Chunk}s become searchable within the knowledge base's
# scope.
#
# == Resource hierarchy
#
#   User → **KnowledgeBase** → Document → Chunk
#
# == Table: +knowledge_bases+
#
# @!attribute [r] id
#   @return [Integer] primary key (auto-increment)
# @!attribute [rw] name
#   @return [String] human-readable name (e.g. "Company Policies").
#     Must be unique per user (enforced by DB unique index on
#     +[user_id, name]+).
# @!attribute [rw] description
#   @return [String, nil] optional description of what this KB contains
#     (max 1000 characters)
# @!attribute [rw] user_id
#   @return [Integer] foreign key to the owning {User} (indexed, NOT NULL)
# @!attribute [r] created_at
#   @return [DateTime]
# @!attribute [r] updated_at
#   @return [DateTime]
#
# == Validations
#
# - +name+ — required, max 255 chars, unique within the user's KBs
#   (so different users can have KBs with the same name, but one user
#   cannot).
# - +description+ — optional, max 1000 chars.
#
# @example Creating a knowledge base
#   kb = user.knowledge_bases.create!(
#     name: "Engineering Docs",
#     description: "Internal engineering documentation"
#   )
#
# @example Checking readiness for search
#   if kb.indexed_documents > 0
#     SearchService.new(knowledge_base: kb).search(query: "deployment")
#   end
#
# @see Api::V1::KnowledgeBasesController CRUD + search + ask endpoints
# @see SearchService Semantic search within a KB
# @see RagService RAG Q&A within a KB
class KnowledgeBase < ApplicationRecord
  # @!method user
  #   @return [User] the user who owns this knowledge base.
  #     Required — a knowledge base cannot exist without an owner.
  belongs_to :user

  # @!method documents
  #   @return [ActiveRecord::Associations::CollectionProxy<Document>]
  #     all documents in this knowledge base. Destroying the KB
  #     cascades to destroy all documents (and their chunks).
  has_many :documents, dependent: :destroy

  # Name is required, max 255 chars, and must be unique per user.
  validates :name, presence: true,
                   length: { maximum: 255 },
                   uniqueness: { scope: :user_id, message: "already exists for this user" }

  # Description is optional but capped at 1000 chars.
  validates :description, length: { maximum: 1000 }

  # Count all documents in this knowledge base regardless of status.
  #
  # @return [Integer] total document count
  #
  # @example
  #   kb.total_documents # => 12
  def total_documents
    documents.count
  end

  # Count only documents that have been successfully processed and
  # are ready for search. Used by controllers to check whether the
  # KB is searchable before calling {SearchService}.
  #
  # @return [Integer] number of documents with status "indexed"
  #
  # @example
  #   kb.indexed_documents # => 10
  def indexed_documents
    documents.where(status: "indexed").count
  end

  # Count all chunks across every document in this knowledge base.
  # Useful for displaying storage/usage statistics.
  #
  # @return [Integer] total chunk count across all documents
  #
  # @example
  #   kb.total_chunks # => 87
  def total_chunks
    Chunk.joins(:document).where(documents: { knowledge_base_id: id }).count
  end
end
