require 'rails_helper'

RSpec.describe Chunk, type: :model do
  describe 'validations' do
    subject { build(:chunk) }

    it { should validate_presence_of(:content) }
    it { should validate_presence_of(:chunk_index) }
    it { should validate_numericality_of(:chunk_index).only_integer.is_greater_than_or_equal_to(0) }

    it 'validates uniqueness of chunk_index scoped to document' do
      document = create(:document)
      create(:chunk, document: document, chunk_index: 0)
      duplicate = build(:chunk, document: document, chunk_index: 0)
      expect(duplicate).not_to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:document) }
  end

  describe 'scopes' do
    describe '.for_knowledge_base' do
      it 'returns chunks for a specific knowledge base' do
        kb1 = create(:knowledge_base)
        kb2 = create(:knowledge_base)
        doc1 = create(:document, knowledge_base: kb1)
        doc2 = create(:document, knowledge_base: kb2)
        chunk1 = create(:chunk, document: doc1)
        chunk2 = create(:chunk, document: doc2)

        expect(Chunk.for_knowledge_base(kb1.id)).to include(chunk1)
        expect(Chunk.for_knowledge_base(kb1.id)).not_to include(chunk2)
      end
    end
  end

  describe '.search_similar' do
    let(:knowledge_base) { create(:knowledge_base) }
    let(:document) { create(:document, knowledge_base: knowledge_base) }
    let!(:chunks) do
      3.times.map do |i|
        create(:chunk, document: document, chunk_index: i)
      end
    end

    it 'returns chunks ordered by similarity' do
      query_embedding = Array.new(768) { rand(-1.0..1.0) }
      results = Chunk.search_similar(query_embedding, knowledge_base_id: knowledge_base.id, limit: 2)
      expect(results.to_a.size).to eq(2)
    end

    it 'only returns chunks from the specified knowledge base' do
      other_kb = create(:knowledge_base)
      other_doc = create(:document, knowledge_base: other_kb)
      create(:chunk, document: other_doc)

      query_embedding = Array.new(768) { rand(-1.0..1.0) }
      results = Chunk.search_similar(query_embedding, knowledge_base_id: knowledge_base.id)

      results.each do |chunk|
        expect(chunk.document.knowledge_base_id).to eq(knowledge_base.id)
      end
    end
  end
end
