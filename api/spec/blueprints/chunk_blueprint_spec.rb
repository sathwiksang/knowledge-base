# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChunkBlueprint do
  let(:user) { create(:user) }
  let(:knowledge_base) { create(:knowledge_base, user: user) }
  let(:document) { create(:document, knowledge_base: knowledge_base) }
  let(:chunk) do
    create(:chunk,
      document: document,
      content: "JWT tokens are issued on login.",
      chunk_index: 0
    )
  end

  describe 'default view' do
    subject(:rendered) { described_class.render_as_hash(chunk) }

    it 'includes id' do
      expect(rendered[:id]).to eq(chunk.id)
    end

    it 'includes content' do
      expect(rendered[:content]).to eq("JWT tokens are issued on login.")
    end

    it 'includes chunk_index' do
      expect(rendered[:chunk_index]).to eq(0)
    end

    it 'includes created_at' do
      expect(rendered[:created_at]).to be_present
    end

    it 'does not include embedding' do
      expect(rendered).not_to have_key(:embedding)
    end

    it 'does not include similarity_score' do
      expect(rendered).not_to have_key(:similarity_score)
    end
  end

  describe ':with_similarity view' do
    let(:scores) { { chunk.id => 0.8723 } }

    subject(:rendered) do
      described_class.render_as_hash(chunk, view: :with_similarity, similarity_scores: scores)
    end

    it 'includes similarity_score from options' do
      expect(rendered[:similarity_score]).to eq(0.8723)
    end

    it 'includes default fields' do
      expect(rendered[:id]).to eq(chunk.id)
      expect(rendered[:content]).to eq("JWT tokens are issued on login.")
      expect(rendered[:chunk_index]).to eq(0)
    end

    context 'when no score is available for this chunk' do
      let(:scores) { { 99999 => 0.5 } }

      it 'returns nil for similarity_score' do
        expect(rendered[:similarity_score]).to be_nil
      end
    end

    context 'when similarity_scores option is nil' do
      subject(:rendered) do
        described_class.render_as_hash(chunk, view: :with_similarity)
      end

      it 'returns nil for similarity_score' do
        expect(rendered[:similarity_score]).to be_nil
      end
    end
  end
end
