class CreateKnowledgeBases < ActiveRecord::Migration[8.1]
  def change
    create_table :knowledge_bases do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :knowledge_bases, [ :user_id, :name ], unique: true
  end
end
