require 'rails_helper'

RSpec.describe KnowledgeBase, type: :model do
  describe 'validations' do
    subject { build(:knowledge_base) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(255) }
    it { should validate_length_of(:description).is_at_most(1000) }

    it 'validates uniqueness of name scoped to user' do
      user = create(:user)
      create(:knowledge_base, user: user, name: 'Test KB')
      duplicate = build(:knowledge_base, user: user, name: 'Test KB')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('already exists for this user')
    end

    it 'allows same name for different users' do
      kb1 = create(:knowledge_base, name: 'Test KB')
      kb2 = build(:knowledge_base, name: 'Test KB')
      expect(kb2).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:documents).dependent(:destroy) }
  end

  describe 'instance methods' do
    let(:knowledge_base) { create(:knowledge_base) }

    describe '#total_documents' do
      it 'returns the count of documents' do
        create_list(:document, 3, knowledge_base: knowledge_base)
        expect(knowledge_base.total_documents).to eq(3)
      end
    end

    describe '#indexed_documents' do
      it 'returns the count of indexed documents' do
        create_list(:document, 2, knowledge_base: knowledge_base, status: 'indexed')
        create(:document, knowledge_base: knowledge_base, status: 'pending')
        expect(knowledge_base.indexed_documents).to eq(2)
      end
    end

    describe '#total_chunks' do
      it 'returns the count of chunks across all documents' do
        doc1 = create(:document, knowledge_base: knowledge_base)
        doc2 = create(:document, knowledge_base: knowledge_base)
        create_list(:chunk, 2, document: doc1)
        create_list(:chunk, 3, document: doc2)
        expect(knowledge_base.total_chunks).to eq(5)
      end
    end
  end
end
