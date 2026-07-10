# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchResultBlueprint do
  let(:result) do
    SearchService::SearchResult.new(
      rank: 1,
      chunk_id: 42,
      content: "JWT tokens are issued on login and expire after 24 hours.",
      similarity_score: 0.8723,
      document_id: 5,
      document_title: "Auth Guide",
      chunk_index: 3
    )
  end

  describe 'default view' do
    subject(:rendered) { described_class.render_as_hash(result) }

    it 'uses chunk_id as the identifier' do
      expect(rendered[:chunk_id]).to eq(42)
    end

    it 'includes rank' do
      expect(rendered[:rank]).to eq(1)
    end

    it 'includes content' do
      expect(rendered[:content]).to eq("JWT tokens are issued on login and expire after 24 hours.")
    end

    it 'includes similarity_score' do
      expect(rendered[:similarity_score]).to eq(0.8723)
    end

    it 'includes chunk_index' do
      expect(rendered[:chunk_index]).to eq(3)
    end

    it 'includes nested document with id and title' do
      doc = rendered[:document]
      expect(doc[:id]).to eq(5)
      expect(doc[:title]).to eq("Auth Guide")
    end
  end

  describe ':detailed view' do
    subject(:rendered) { described_class.render_as_hash(result, view: :detailed) }

    it 'includes all default fields' do
      expect(rendered[:chunk_id]).to eq(42)
      expect(rendered[:rank]).to eq(1)
      expect(rendered[:content]).to be_present
      expect(rendered[:similarity_score]).to eq(0.8723)
      expect(rendered[:chunk_index]).to eq(3)
    end

    it 'includes flat document_id' do
      expect(rendered[:document_id]).to eq(5)
    end

    it 'includes flat document_title' do
      expect(rendered[:document_title]).to eq("Auth Guide")
    end
  end

  describe 'collection rendering' do
    let(:results) do
      [
        result,
        SearchService::SearchResult.new(
          rank: 2,
          chunk_id: 43,
          content: "Refresh tokens last 7 days.",
          similarity_score: 0.7654,
          document_id: 5,
          document_title: "Auth Guide",
          chunk_index: 4
        )
      ]
    end

    subject(:rendered) { described_class.render_as_hash(results) }

    it 'serializes an array of results' do
      expect(rendered).to be_an(Array)
      expect(rendered.size).to eq(2)
    end

    it 'preserves rank ordering' do
      expect(rendered[0][:rank]).to eq(1)
      expect(rendered[1][:rank]).to eq(2)
    end
  end
end
