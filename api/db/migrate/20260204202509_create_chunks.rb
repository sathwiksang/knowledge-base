class CreateChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :chunks do |t|
      t.references :document, null: false, foreign_key: true
      t.text :content, null: false
      t.integer :chunk_index, null: false
      t.vector :embedding, limit: 768  # nomic-embed-text produces 768 dimensions

      t.timestamps
    end

    add_index :chunks, [ :document_id, :chunk_index ], unique: true
  end
end
