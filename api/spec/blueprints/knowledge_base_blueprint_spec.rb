# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeBaseBlueprint do
  let(:user) { create(:user) }
  let(:knowledge_base) { create(:knowledge_base, user: user, name: "Engineering Docs", description: "Internal docs") }

  describe 'default view' do
    subject(:rendered) { described_class.render_as_hash(knowledge_base) }

    it 'includes id' do
      expect(rendered[:id]).to eq(knowledge_base.id)
    end

    it 'includes name' do
      expect(rendered[:name]).to eq("Engineering Docs")
    end

    it 'includes description' do
      expect(rendered[:description]).to eq("Internal docs")
    end

    it 'includes timestamps' do
      expect(rendered[:created_at]).to be_present
      expect(rendered[:updated_at]).to be_present
    end

    it 'does not include stats' do
      expect(rendered).not_to have_key(:total_documents)
      expect(rendered).not_to have_key(:indexed_documents)
      expect(rendered).not_to have_key(:total_chunks)
    end
  end

  describe ':with_stats view' do
    subject(:rendered) { described_class.render_as_hash(knowledge_base, view: :with_stats) }

    it 'includes total_documents' do
      expect(rendered[:total_documents]).to eq(0)
    end

    it 'includes indexed_documents' do
      expect(rendered[:indexed_documents]).to eq(0)
    end

    it 'includes total_chunks' do
      expect(rendered[:total_chunks]).to eq(0)
    end

    context 'with documents' do
      before do
        create(:document, knowledge_base: knowledge_base, status: "indexed")
        create(:document, knowledge_base: knowledge_base, status: "pending")
      end

      it 'counts documents correctly' do
        expect(rendered[:total_documents]).to eq(2)
        expect(rendered[:indexed_documents]).to eq(1)
      end
    end

    it 'includes default fields' do
      expect(rendered[:name]).to eq("Engineering Docs")
      expect(rendered[:description]).to eq("Internal docs")
    end
  end

  describe ':with_documents view' do
    let!(:document) do
      create(:document, knowledge_base: knowledge_base, title: "Auth Guide", status: "indexed")
    end

    subject(:rendered) { described_class.render_as_hash(knowledge_base, view: :with_documents) }

    it 'includes nested documents array' do
      expect(rendered[:documents]).to be_an(Array)
      expect(rendered[:documents].size).to eq(1)
    end

    it 'serializes documents with default DocumentBlueprint fields' do
      doc_data = rendered[:documents].first
      expect(doc_data[:id]).to eq(document.id)
      expect(doc_data[:title]).to eq("Auth Guide")
      expect(doc_data[:status]).to eq("indexed")
    end

    it 'includes stats' do
      expect(rendered[:total_documents]).to eq(1)
      expect(rendered[:indexed_documents]).to eq(1)
    end
  end
end
