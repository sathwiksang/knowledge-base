# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::KnowledgeBases#search', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:knowledge_base) { create(:knowledge_base, user: user) }

  describe 'POST /api/v1/knowledge_bases/:id/search' do
    context 'with indexed documents' do
      let!(:document) { create(:document, :indexed, knowledge_base: knowledge_base) }
      let!(:chunks) do
        [
          create(:chunk, document: document, content: 'Ruby is a programming language', chunk_index: 0),
          create(:chunk, document: document, content: 'Rails is a web framework', chunk_index: 1),
          create(:chunk, document: document, content: 'PostgreSQL is a database', chunk_index: 2)
        ]
      end

      before do
        # Mock the embedding service to avoid calling Ollama in tests
        mock_embedding = Array.new(768) { rand(-1.0..1.0) }
        allow_any_instance_of(EmbeddingService).to receive(:generate).and_return(mock_embedding)
      end

      it 'returns search results' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: 'programming language' },
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response['results']).to be_an(Array)
        expect(json_response['query']).to eq('programming language')
        expect(json_response['knowledge_base_id']).to eq(knowledge_base.id)
        expect(json_response['total_chunks_searched']).to eq(3)
      end

      it 'returns results with expected structure' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: 'test' },
             headers: headers

        result = json_response['results'].first

        expect(result).to have_key('rank')
        expect(result).to have_key('chunk_id')
        expect(result).to have_key('content')
        expect(result).to have_key('similarity_score')
        expect(result).to have_key('document_id')
        expect(result).to have_key('document_title')
      end

      it 'respects limit parameter' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: 'test', limit: 2 },
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to be <= 2
      end

      it 'includes search timing information' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: 'test' },
             headers: headers

        expect(json_response['search_time_ms']).to be_a(Numeric)
      end

      it 'returns results ordered by rank' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: 'test' },
             headers: headers

        ranks = json_response['results'].map { |r| r['rank'] }
        expect(ranks).to eq(ranks.sort)
      end

      it 'caps limit at maximum' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: 'test', limit: 100 },
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response['results'].length).to be <= SearchService::MAX_LIMIT
      end

      context 'with min_similarity parameter' do
        it 'filters results below threshold' do
          post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
               params: { query: 'test', min_similarity: 0.99 },
               headers: headers

          expect(response).to have_http_status(:ok)
          json_response['results'].each do |result|
            expect(result['similarity_score']).to be >= 0.99
          end
        end
      end
    end

    context 'without indexed documents' do
      it 'returns error message' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: 'test' },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('No indexed documents')
        expect(json_response['hint']).to be_present
      end

      it 'includes knowledge_base_id in error response' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: 'test' },
             headers: headers

        expect(json_response['knowledge_base_id']).to eq(knowledge_base.id)
      end
    end

    context 'with pending documents only' do
      let!(:document) { create(:document, knowledge_base: knowledge_base, status: 'pending') }

      it 'returns error message' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: 'test' },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('No indexed documents')
      end
    end

    context 'with missing query' do
      let!(:document) { create(:document, :indexed, knowledge_base: knowledge_base) }
      let!(:chunk) { create(:chunk, document: document) }

      it 'returns validation error' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: {},
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('Query parameter is required')
      end

      it 'returns validation error for blank query' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: '' },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('Query parameter is required')
      end
    end

    context 'with embedding generation failure' do
      let!(:document) { create(:document, :indexed, knowledge_base: knowledge_base) }
      let!(:chunk) { create(:chunk, document: document) }

      before do
        allow_any_instance_of(EmbeddingService).to receive(:generate).and_return(nil)
      end

      it 'returns error response' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: 'test' },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('embedding')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: 'test' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with non-existent knowledge base' do
      it 'returns not found' do
        post '/api/v1/knowledge_bases/99999/search',
             params: { query: 'test' },
             headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with another user knowledge base' do
      let(:other_kb) { create(:knowledge_base) }

      it 'returns not found' do
        post "/api/v1/knowledge_bases/#{other_kb.id}/search",
             params: { query: 'test' },
             headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/knowledge_bases/:id/ask' do
    context 'with indexed documents' do
      # Use a fixed embedding to ensure consistent similarity scores
      let(:fixed_embedding) { Array.new(768) { |i| Math.sin(i * 0.1) } }
      let!(:document) { create(:document, :indexed, knowledge_base: knowledge_base, title: 'Ruby Guide') }
      let!(:chunks) do
        [
          create(:chunk, document: document, content: 'Ruby is a dynamic programming language', chunk_index: 0, embedding: fixed_embedding),
          create(:chunk, document: document, content: 'Ruby supports object-oriented programming', chunk_index: 1, embedding: fixed_embedding)
        ]
      end

      before do
        # Return same embedding to ensure high similarity with chunk embeddings
        allow_any_instance_of(EmbeddingService).to receive(:generate).and_return(fixed_embedding)

        # Mock the LLM service to avoid calling Ollama in tests
        allow_any_instance_of(LlmService).to receive(:answer_question).and_return({
          answer: 'Ruby is a dynamic programming language that supports multiple programming paradigms.',
          model: 'llama3.2:3b'
        })
      end

      it 'returns successful RAG response' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/ask",
             params: { question: 'What is Ruby?' },
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response['answer']).to be_present
        expect(json_response['question']).to eq('What is Ruby?')
        expect(json_response['knowledge_base_id']).to eq(knowledge_base.id)
      end

      it 'includes source citations' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/ask",
             params: { question: 'What is Ruby?' },
             headers: headers

        expect(json_response['sources']).to be_an(Array)
        expect(json_response['sources']).not_to be_empty

        first_source = json_response['sources'].first
        expect(first_source).to have_key('document_id')
        expect(first_source).to have_key('document_title')
        expect(first_source).to have_key('similarity_score')
        expect(first_source).to have_key('content_preview')
      end

      it 'includes model information' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/ask",
             params: { question: 'What is Ruby?' },
             headers: headers

        expect(json_response['model']).to be_present
      end

      it 'includes processing metadata' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/ask",
             params: { question: 'What is Ruby?' },
             headers: headers

        expect(json_response['chunks_used']).to be_a(Integer)
        expect(json_response['total_chunks_searched']).to be_a(Integer)
        expect(json_response['processing_time_ms']).to be_a(Numeric)
      end

      it 'respects num_chunks parameter' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/ask",
             params: { question: 'What is Ruby?', num_chunks: 1 },
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response['chunks_used']).to be <= 1
      end

      it 'excludes sources when include_sources is false' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/ask",
             params: { question: 'What is Ruby?', include_sources: false },
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response['sources']).to be_empty
      end
    end

    context 'without indexed documents' do
      it 'returns error message' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/ask",
             params: { question: 'What is Ruby?' },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('No indexed documents')
        expect(json_response['hint']).to be_present
      end
    end

    context 'with missing question' do
      let!(:document) { create(:document, :indexed, knowledge_base: knowledge_base) }
      let!(:chunk) { create(:chunk, document: document) }

      it 'returns validation error' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/ask",
             params: {},
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('Question parameter is required')
      end

      it 'returns validation error for blank question' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/ask",
             params: { question: '' },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('Question parameter is required')
      end
    end

    context 'with LLM generation failure' do
      let(:fixed_embedding) { Array.new(768) { |i| Math.sin(i * 0.1) } }
      let!(:document) { create(:document, :indexed, knowledge_base: knowledge_base) }
      let!(:chunk) { create(:chunk, document: document, content: 'Some content about Ruby', embedding: fixed_embedding) }

      before do
        allow_any_instance_of(EmbeddingService).to receive(:generate).and_return(fixed_embedding)
        allow_any_instance_of(LlmService).to receive(:answer_question)
          .and_raise(LlmService::LlmError, 'LLM connection failed')
      end

      it 'returns error response' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/ask",
             params: { question: 'What is Ruby?' },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('Failed to generate answer')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/ask",
             params: { question: 'What is Ruby?' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with non-existent knowledge base' do
      it 'returns not found' do
        post '/api/v1/knowledge_bases/99999/ask',
             params: { question: 'What is Ruby?' },
             headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with another user knowledge base' do
      let(:other_kb) { create(:knowledge_base) }

      it 'returns not found' do
        post "/api/v1/knowledge_bases/#{other_kb.id}/ask",
             params: { question: 'What is Ruby?' },
             headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
