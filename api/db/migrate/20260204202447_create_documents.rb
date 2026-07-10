class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :knowledge_base, null: false, foreign_key: true
      t.string :title, null: false
      t.text :content, null: false
      t.string :status, null: false, default: 'pending'
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :documents, :status
    add_index :documents, :metadata, using: :gin
  end
end
