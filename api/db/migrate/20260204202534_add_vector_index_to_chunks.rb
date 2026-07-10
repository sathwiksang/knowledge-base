class AddVectorIndexToChunks < ActiveRecord::Migration[8.1]
  def change
    # HNSW index for approximate nearest neighbor search
    # Works well without training data, good for dynamic datasets
    add_index :chunks, :embedding,
              using: :hnsw,
              opclass: :vector_cosine_ops,
              name: 'index_chunks_on_embedding_hnsw'
  end
end
