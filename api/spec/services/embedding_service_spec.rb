# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmbeddingService do
  let(:mock_client) { instance_double(Clients::OllamaClient) }
  let(:service) { described_class.new(client: mock_client) }
  let(:mock_embedding) { Array.new(768) { rand(-1.0..1.0) } }

  describe '#generate' do
    before do
      allow(mock_client).to receive(:embed).and_return(mock_embedding)
    end

    it 'generates embedding for text' do
      result = service.generate('Test text')

      expect(result).to be_an(Array)
      expect(result.length).to eq(768)
    end

    it 'returns nil for blank text' do
      expect(service.generate('')).to be_nil
      expect(service.generate(nil)).to be_nil
      expect(service.generate('   ')).to be_nil
    end

    it 'normalizes whitespace in text' do
      service.generate("Text   with\n\nmultiple   spaces")

      expect(mock_client).to have_received(:embed).with('Text with multiple spaces')
    end

    it 'truncates very long text' do
      long_text = 'a' * 10_000
      service.generate(long_text)

      expect(mock_client).to have_received(:embed) do |text|
        expect(text.length).to be <= 8000
      end
    end

    context 'when embedding has wrong dimensions' do
      before do
        allow(mock_client).to receive(:embed).and_return(Array.new(512) { 0.1 })
      end

      it 'raises DimensionMismatchError' do
        expect { service.generate('Test text') }
          .to raise_error(EmbeddingService::DimensionMismatchError, /expected 768/)
      end
    end

    context 'when client raises error' do
      before do
        allow(mock_client).to receive(:embed)
          .and_raise(Clients::OllamaClient::ConnectionError, 'Connection refused')
      end

      it 'raises EmbeddingError' do
        expect { service.generate('Test text') }
          .to raise_error(EmbeddingService::EmbeddingError, /Connection refused/)
      end
    end
  end

  describe '#generate_batch' do
    let(:texts) { [ 'Text 1', 'Text 2', 'Text 3' ] }

    before do
      allow(mock_client).to receive(:embed).and_return(mock_embedding)
    end

    it 'generates embeddings for multiple texts' do
      results = service.generate_batch(texts)

      expect(results.length).to eq(3)
      expect(results).to all(be_an(Array).and(have_attributes(length: 768)))
    end

    it 'returns empty array for empty input' do
      expect(service.generate_batch([])).to eq([])
      expect(service.generate_batch(nil)).to eq([])
    end

    it 'includes nil for blank texts in the batch' do
      results = service.generate_batch([ 'Valid', '', 'Also valid' ])

      expect(results[0]).to be_an(Array)
      expect(results[1]).to be_nil
      expect(results[2]).to be_an(Array)
    end
  end

  describe '#generate_batch_with_indices' do
    before do
      allow(mock_client).to receive(:embed).and_return(mock_embedding)
    end

    it 'returns hash with indices as keys' do
      texts = [ 'Text A', 'Text B' ]
      results = service.generate_batch_with_indices(texts)

      expect(results).to be_a(Hash)
      expect(results.keys).to eq([ 0, 1 ])
    end

    it 'returns empty hash for empty input' do
      expect(service.generate_batch_with_indices([])).to eq({})
    end
  end

  describe '#cosine_similarity' do
    let(:embedding1) { Array.new(768) { 1.0 } }
    let(:embedding2) { Array.new(768) { 1.0 } }
    let(:orthogonal) { Array.new(768) { |i| i.even? ? 1.0 : -1.0 } }

    it 'returns 1.0 for identical embeddings' do
      similarity = service.cosine_similarity(embedding1, embedding2)
      expect(similarity).to be_within(0.0001).of(1.0)
    end

    it 'returns 0.0 for orthogonal embeddings' do
      e1 = [ 1.0, 0.0, 0.0 ] + Array.new(765) { 0.0 }
      e2 = [ 0.0, 1.0, 0.0 ] + Array.new(765) { 0.0 }

      similarity = service.cosine_similarity(e1, e2)
      expect(similarity).to be_within(0.0001).of(0.0)
    end

    it 'returns 0.0 for blank embeddings' do
      expect(service.cosine_similarity(nil, embedding1)).to eq(0.0)
      expect(service.cosine_similarity(embedding1, nil)).to eq(0.0)
      expect(service.cosine_similarity([], embedding1)).to eq(0.0)
    end
  end

  describe '#available?' do
    it 'returns true when client is healthy and model available' do
      allow(mock_client).to receive(:health_check).and_return(true)
      allow(mock_client).to receive(:model_available?).and_return(true)

      expect(service.available?).to be true
    end

    it 'returns false when client is unhealthy' do
      allow(mock_client).to receive(:health_check).and_return(false)

      expect(service.available?).to be false
    end
  end

  describe '#embedding_model_name' do
    it 'returns configured model name' do
      expect(service.embedding_model_name).to eq('nomic-embed-text')
    end
  end

  describe '#dimensions' do
    it 'returns 768' do
      expect(service.dimensions).to eq(768)
    end
  end
end
