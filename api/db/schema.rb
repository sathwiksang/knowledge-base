# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_04_202534) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"
  enable_extension "uuid-ossp"
  enable_extension "vector"

  create_table "chunks", force: :cascade do |t|
    t.integer "chunk_index", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.vector "embedding", limit: 768
    t.datetime "updated_at", null: false
    t.index ["document_id", "chunk_index"], name: "index_chunks_on_document_id_and_chunk_index", unique: true
    t.index ["document_id"], name: "index_chunks_on_document_id"
    t.index ["embedding"], name: "index_chunks_on_embedding_hnsw", opclass: :vector_cosine_ops, using: :hnsw
  end

  create_table "documents", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "knowledge_base_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["knowledge_base_id"], name: "index_documents_on_knowledge_base_id"
    t.index ["metadata"], name: "index_documents_on_metadata", using: :gin
    t.index ["status"], name: "index_documents_on_status"
  end

  create_table "knowledge_bases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_knowledge_bases_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_knowledge_bases_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "chunks", "documents"
  add_foreign_key "documents", "knowledge_bases"
  add_foreign_key "knowledge_bases", "users"
end
