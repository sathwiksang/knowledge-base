# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentBlueprint do
  let(:user) { create(:user) }
  let(:knowledge_base) { create(:knowledge_base, user: user) }
  let(:document) do
    create(:document,
      knowledge_base: knowledge_base,
      title: "Auth Guide",
      content: "This guide explains how JWT authentication works in our API. " * 20,
      status: "indexed"
    )
  end

  describe 'default view' do
    subject(:rendered) { described_class.render_as_hash(document) }

    it 'includes id' do
      expect(rendered[:id]).to eq(document.id)
    end

    it 'includes title' do
      expect(rendered[:title]).to eq("Auth Guide")
    end

    it 'includes status' do
      expect(rendered[:status]).to eq("indexed")
    end

    it 'includes content_preview truncated to 200 chars' do
      expect(rendered[:content_preview]).to be_present
      expect(rendered[:content_preview].length).to be <= 200
    end

    it 'includes timestamps' do
      expect(rendered[:created_at]).to be_present
      expect(rendered[:updated_at]).to be_present
    end

    it 'does not include full content' do
      expect(rendered).not_to have_key(:content)
    end

    it 'does not include metadata' do
      expect(rendered).not_to have_key(:metadata)
    end
  end

  describe ':minimal view' do
    subject(:rendered) { described_class.render_as_hash(document, view: :minimal) }

    it 'includes id and title' do
      expect(rendered[:id]).to eq(document.id)
      expect(rendered[:title]).to eq("Auth Guide")
    end

    it 'does not include full content' do
      expect(rendered).not_to have_key(:content)
    end

    it 'does not include metadata' do
      expect(rendered).not_to have_key(:metadata)
    end
  end

  describe ':detailed view' do
    subject(:rendered) { described_class.render_as_hash(document, view: :detailed) }

    it 'includes full content' do
      expect(rendered[:content]).to eq(document.content)
    end

    it 'includes metadata' do
      expect(rendered).to have_key(:metadata)
    end

    it 'includes chunks_count' do
      expect(rendered[:chunks_count]).to eq(0)
    end

    it 'includes default fields' do
      expect(rendered[:title]).to eq("Auth Guide")
      expect(rendered[:status]).to eq("indexed")
    end
  end

  describe ':with_chunks view' do
    let!(:chunk) do
      create(:chunk,
        document: document,
        content: "Chunk text",
        chunk_index: 0
      )
    end

    subject(:rendered) { described_class.render_as_hash(document, view: :with_chunks) }

    it 'includes nested chunks array' do
      expect(rendered[:chunks]).to be_an(Array)
      expect(rendered[:chunks].size).to eq(1)
    end

    it 'serializes chunks with ChunkBlueprint fields' do
      chunk_data = rendered[:chunks].first
      expect(chunk_data[:id]).to eq(chunk.id)
      expect(chunk_data[:content]).to eq("Chunk text")
      expect(chunk_data[:chunk_index]).to eq(0)
    end

    it 'includes detailed fields' do
      expect(rendered[:content]).to be_present
      expect(rendered[:chunks_count]).to eq(1)
    end
  end
end
