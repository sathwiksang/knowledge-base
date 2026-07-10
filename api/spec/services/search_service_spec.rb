# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchService do
  let(:user) { create(:user) }
  let(:knowledge_base) { create(:knowledge_base, user: user) }
  let(:document) { create(:document, :indexed, knowledge_base: knowledge_base) }
  let(:mock_embedding_service) { instance_double(EmbeddingService) }
  let(:mock_embedding) { Array.new(768) { rand(-1.0..1.0) } }

  let(:service) do
    described_class.new(
      knowledge_base: knowledge_base,
      embedding_service: mock_embedding_service
    )
  end

  before do
    allow(mock_embedding_service).to receive(:generate).and_return(mock_embedding)

    # Create test chunks with different content
    create(:chunk, document: document, content: 'Ruby is a programming language', chunk_index: 0)
    create(:chunk, document: document, content: 'Rails is a web framework', chunk_index: 1)
    create(:chunk, document: document, content: 'PostgreSQL is a database', chunk_index: 2)
  end

  describe '#search' do
    context 'with valid query' do
      it 'returns a SearchResponse with expected keys' do
        response = service.search(query: 'programming language')

        expect(response).to be_a(SearchService::SearchResponse)
        expect(response.results).to be_an(Array)
        expect(response.query).to eq('programming language')
        expect(response.total_chunks_searched).to eq(3)
        expect(response.knowledge_base_id).to eq(knowledge_base.id)
        expect(response.search_time_ms).to be_a(Numeric)
      end

      it 'generates embedding for query' do
        service.search(query: 'test query')

        expect(mock_embedding_service).to have_received(:generate).with('test query')
      end

      it 'returns results with correct structure' do
        response = service.search(query: 'test')
        result = response.results.first

        expect(result).to be_a(SearchService::SearchResult)
        expect(result.rank).to eq(1)
        expect(result.chunk_id).to be_present
        expect(result.content).to be_present
        expect(result.similarity_score).to be_a(Float)
        expect(result.document_id).to eq(document.id)
        expect(result.document_title).to eq(document.title)
      end

      it 'returns results ordered by similarity (most similar first)' do
        response = service.search(query: 'test')

        ranks = response.results.map(&:rank)
        expect(ranks).to eq(ranks.sort)
      end

      it 'similarity scores are between 0 and 1' do
        response = service.search(query: 'test')

        response.results.each do |result|
          expect(result.similarity_score).to be >= 0.0
          expect(result.similarity_score).to be <= 1.0
        end
      end
    end

    context 'with limit parameter' do
      it 'respects the limit parameter' do
        response = service.search(query: 'test', limit: 2)

        expect(response.results.length).to be <= 2
      end

      it 'uses default limit when not specified' do
        response = service.search(query: 'test')

        expect(response.results.length).to be <= SearchService::DEFAULT_LIMIT
      end

      it 'caps limit at MAX_LIMIT' do
        response = service.search(query: 'test', limit: 100)

        expect(response.results.length).to be <= SearchService::MAX_LIMIT
      end

      it 'uses default limit for invalid values' do
        response = service.search(query: 'test', limit: -5)

        expect(response.results.length).to be <= SearchService::DEFAULT_LIMIT
      end

      it 'converts string limit to integer' do
        response = service.search(query: 'test', limit: '2')

        expect(response.results.length).to be <= 2
      end
    end

    context 'with min_similarity parameter' do
      it 'filters results below minimum similarity' do
        response = service.search(query: 'test', min_similarity: 0.99)

        # With random embeddings, results are unlikely to have >0.99 similarity
        # All results should either be filtered or meet the threshold
        response.results.each do |result|
          expect(result.similarity_score).to be >= 0.99
        end
      end
    end

    context 'with blank query' do
      it 'returns error response' do
        response = service.search(query: '')

        expect(response.success?).to be false
        expect(response.error).to include('required')
        expect(response.results).to be_empty
      end

      it 'returns error for nil query' do
        response = service.search(query: nil)

        expect(response.success?).to be false
        expect(response.error).to include('required')
      end
    end

    context 'with too short query' do
      it 'returns error response' do
        response = service.search(query: 'a')

        expect(response.success?).to be false
        expect(response.error).to include('at least')
      end
    end

    context 'with too long query' do
      it 'returns error response' do
        long_query = 'a' * 1001
        response = service.search(query: long_query)

        expect(response.success?).to be false
        expect(response.error).to include('exceed')
      end
    end

    context 'with no indexed documents' do
      let(:empty_kb) { create(:knowledge_base, user: user) }
      let(:empty_service) do
        described_class.new(
          knowledge_base: empty_kb,
          embedding_service: mock_embedding_service
        )
      end

      it 'returns error response' do
        response = empty_service.search(query: 'test')

        expect(response.success?).to be false
        expect(response.error).to include('No indexed documents')
        expect(response.results).to be_empty
      end
    end

    context 'when embedding generation fails' do
      before do
        allow(mock_embedding_service).to receive(:generate).and_return(nil)
      end

      it 'returns error response' do
        response = service.search(query: 'test')

        expect(response.success?).to be false
        expect(response.error).to include('embedding')
        expect(response.results).to be_empty
      end
    end

    context 'when embedding service raises error' do
      before do
        allow(mock_embedding_service).to receive(:generate)
          .and_raise(EmbeddingService::EmbeddingError, 'Connection failed')
      end

      it 'returns error response' do
        response = service.search(query: 'test')

        expect(response.success?).to be false
        expect(response.error).to include('Connection failed')
      end
    end
  end

  describe '#multi_search' do
    it 'combines results from multiple queries' do
      results = service.multi_search(queries: [ 'Ruby', 'Rails' ], limit: 5)

      expect(results).to be_an(Array)
      expect(results.length).to be <= 5
    end

    it 'deduplicates results by chunk_id' do
      results = service.multi_search(queries: [ 'Ruby', 'Ruby' ], limit: 10)

      chunk_ids = results.map(&:chunk_id)
      expect(chunk_ids.uniq.length).to eq(chunk_ids.length)
    end

    it 'sorts combined results by similarity' do
      results = service.multi_search(queries: [ 'Ruby', 'Rails' ], limit: 5)

      scores = results.map(&:similarity_score)
      expect(scores).to eq(scores.sort.reverse)
    end
  end

  describe '#suggest_queries' do
    it 'returns document titles matching prefix' do
      create(:document, :indexed, knowledge_base: knowledge_base, title: 'Ruby Tutorial')
      create(:document, :indexed, knowledge_base: knowledge_base, title: 'Ruby Guide')
      create(:document, :indexed, knowledge_base: knowledge_base, title: 'Python Basics')

      suggestions = service.suggest_queries(prefix: 'Ruby')

      expect(suggestions).to include('Ruby Tutorial', 'Ruby Guide')
      expect(suggestions).not_to include('Python Basics')
    end

    it 'returns empty array for short prefix' do
      suggestions = service.suggest_queries(prefix: 'R')

      expect(suggestions).to be_empty
    end

    it 'returns empty array for blank prefix' do
      suggestions = service.suggest_queries(prefix: '')

      expect(suggestions).to be_empty
    end

    it 'limits number of suggestions' do
      5.times { |i| create(:document, :indexed, knowledge_base: knowledge_base, title: "Ruby Doc #{i}") }

      suggestions = service.suggest_queries(prefix: 'Ruby', limit: 3)

      expect(suggestions.length).to be <= 3
    end
  end

  describe 'SearchResponse' do
    let(:response) do
      SearchService::SearchResponse.new(
        results: [],
        query: 'test',
        total_chunks_searched: 10,
        knowledge_base_id: 1,
        search_time_ms: 5.5,
        error: nil
      )
    end

    it 'success? returns true when no error' do
      expect(response.success?).to be true
    end

    it 'success? returns false when error present' do
      response.error = 'Something went wrong'
      expect(response.success?).to be false
    end

    it 'to_h returns hash representation' do
      hash = response.to_h

      expect(hash[:query]).to eq('test')
      expect(hash[:total_chunks_searched]).to eq(10)
      expect(hash[:knowledge_base_id]).to eq(1)
      expect(hash[:search_time_ms]).to eq(5.5)
    end

    it 'to_h includes error when present' do
      response.error = 'Error message'
      hash = response.to_h

      expect(hash[:error]).to eq('Error message')
    end
  end

  describe 'SearchResult' do
    let(:result) do
      SearchService::SearchResult.new(
        rank: 1,
        chunk_id: 123,
        content: 'Test content',
        similarity_score: 0.85,
        document_id: 456,
        document_title: 'Test Document',
        chunk_index: 0
      )
    end

    it 'has all expected attributes' do
      expect(result.rank).to eq(1)
      expect(result.chunk_id).to eq(123)
      expect(result.content).to eq('Test content')
      expect(result.similarity_score).to eq(0.85)
      expect(result.document_id).to eq(456)
      expect(result.document_title).to eq('Test Document')
      expect(result.chunk_index).to eq(0)
    end

    it 'converts to hash' do
      hash = result.to_h

      expect(hash[:rank]).to eq(1)
      expect(hash[:content]).to eq('Test content')
    end
  end
end
