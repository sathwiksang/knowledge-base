# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Contract Tests', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  shared_examples 'returns request_id in response' do
    it 'includes request_id in response' do
      subject
      expect(json_response).to have_key('request_id')
      expect(json_response['request_id']).to match(/^[a-f0-9\-]{36}$/i)
    end
  end

  shared_examples 'returns proper error structure' do
    it 'includes error field' do
      subject
      expect(json_response).to have_key('error')
    end

    it 'includes timestamp in error' do
      subject
      expect(json_response).to have_key('timestamp')
    end
  end

  describe 'Authentication Endpoints Contract' do
    describe 'POST /api/v1/auth/register' do
      context 'successful registration' do
        subject do
          post '/api/v1/auth/register', params: {
            email: 'contract@test.com',
            password: 'password123',
            password_confirmation: 'password123'
          }
        end

        it 'returns 201 status' do
          subject
          expect(response).to have_http_status(:created)
        end

        it 'returns user object with required fields' do
          subject
          user_response = json_response['user']

          expect(user_response).to have_key('id')
          expect(user_response).to have_key('email')
          expect(user_response).to have_key('created_at')
          expect(user_response).not_to have_key('password_digest')
        end

        it 'returns JWT token' do
          subject
          expect(json_response).to have_key('token')
          expect(json_response['token']).to be_a(String)
          expect(json_response['token'].split('.').length).to eq(3)
        end

        it 'returns success message' do
          subject
          expect(json_response).to have_key('message')
        end

        include_examples 'returns request_id in response'
      end

      context 'failed registration' do
        subject do
          post '/api/v1/auth/register', params: { email: 'invalid' }
        end

        it 'returns 422 status' do
          subject
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'returns errors array' do
          subject
          expect(json_response).to have_key('errors')
          expect(json_response['errors']).to be_an(Array)
        end

        include_examples 'returns request_id in response'
      end
    end

    describe 'POST /api/v1/auth/login' do
      let!(:existing_user) { create(:user, email: 'login@test.com', password: 'password123') }

      context 'successful login' do
        subject do
          post '/api/v1/auth/login', params: {
            email: 'login@test.com',
            password: 'password123'
          }
        end

        it 'returns 200 status' do
          subject
          expect(response).to have_http_status(:ok)
        end

        it 'returns user object' do
          subject
          expect(json_response).to have_key('user')
        end

        it 'returns JWT token' do
          subject
          expect(json_response).to have_key('token')
        end

        include_examples 'returns request_id in response'
      end

      context 'failed login' do
        subject do
          post '/api/v1/auth/login', params: {
            email: 'login@test.com',
            password: 'wrongpassword'
          }
        end

        it 'returns 401 status' do
          subject
          expect(response).to have_http_status(:unauthorized)
        end

        include_examples 'returns proper error structure'
      end
    end
  end

  describe 'Knowledge Base Endpoints Contract' do
    describe 'GET /api/v1/knowledge_bases' do
      subject { get '/api/v1/knowledge_bases', headers: headers }

      before { create_list(:knowledge_base, 3, user: user) }

      it 'returns 200 status' do
        subject
        expect(response).to have_http_status(:ok)
      end

      it 'returns knowledge_bases array' do
        subject
        expect(json_response).to have_key('knowledge_bases')
        expect(json_response['knowledge_bases']).to be_an(Array)
      end

      it 'each knowledge base has required fields' do
        subject
        kb = json_response['knowledge_bases'].first

        expect(kb).to have_key('id')
        expect(kb).to have_key('name')
        expect(kb).to have_key('created_at')
        expect(kb).to have_key('updated_at')
      end

      include_examples 'returns request_id in response'
    end

    describe 'POST /api/v1/knowledge_bases' do
      context 'successful creation' do
        subject do
          post '/api/v1/knowledge_bases',
               params: { name: 'Test KB', description: 'Test description' },
               headers: headers
        end

        it 'returns 201 status' do
          subject
          expect(response).to have_http_status(:created)
        end

        it 'returns knowledge_base object' do
          subject
          expect(json_response).to have_key('knowledge_base')
          expect(json_response['knowledge_base']).to have_key('id')
          expect(json_response['knowledge_base']).to have_key('name')
        end

        include_examples 'returns request_id in response'
      end
    end
  end

  describe 'Document Endpoints Contract' do
    let(:knowledge_base) { create(:knowledge_base, user: user) }

    describe 'GET /api/v1/knowledge_bases/:kb_id/documents' do
      subject { get "/api/v1/knowledge_bases/#{knowledge_base.id}/documents", headers: headers }

      before { create_list(:document, 3, knowledge_base: knowledge_base) }

      it 'returns 200 status' do
        subject
        expect(response).to have_http_status(:ok)
      end

      it 'returns documents array' do
        subject
        expect(json_response).to have_key('documents')
        expect(json_response['documents']).to be_an(Array)
      end

      it 'returns meta information' do
        subject
        expect(json_response).to have_key('meta')
        meta = json_response['meta']

        expect(meta).to have_key('total')
        expect(meta).to have_key('pending')
        expect(meta).to have_key('processing')
        expect(meta).to have_key('indexed')
        expect(meta).to have_key('failed')
      end

      it 'each document has required fields' do
        subject
        doc = json_response['documents'].first

        expect(doc).to have_key('id')
        expect(doc).to have_key('title')
        expect(doc).to have_key('status')
        expect(doc).to have_key('created_at')
      end

      include_examples 'returns request_id in response'
    end

    describe 'POST /api/v1/knowledge_bases/:kb_id/documents' do
      context 'successful creation' do
        subject do
          post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
               params: { title: 'Test Doc', content: 'Test content' },
               headers: headers
        end

        it 'returns 201 status' do
          subject
          expect(response).to have_http_status(:created)
        end

        it 'returns document object' do
          subject
          expect(json_response).to have_key('document')
        end

        it 'returns confirmation message' do
          subject
          expect(json_response).to have_key('message')
        end

        include_examples 'returns request_id in response'
      end
    end
  end

  describe 'Search Endpoints Contract' do
    let(:knowledge_base) { create(:knowledge_base, user: user) }
    let!(:document) { create(:document, :indexed, knowledge_base: knowledge_base) }
    let!(:chunk) { create(:chunk, document: document) }

    before do
      allow_any_instance_of(EmbeddingService).to receive(:generate)
        .and_return(chunk.embedding)
    end

    describe 'POST /api/v1/knowledge_bases/:id/search' do
      context 'successful search' do
        subject do
          post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
               params: { query: 'test query' },
               headers: headers
        end

        it 'returns 200 status' do
          subject
          expect(response).to have_http_status(:ok)
        end

        it 'returns results array' do
          subject
          expect(json_response).to have_key('results')
          expect(json_response['results']).to be_an(Array)
        end

        it 'returns search metadata' do
          subject
          expect(json_response).to have_key('query')
          expect(json_response).to have_key('total_chunks_searched')
          expect(json_response).to have_key('knowledge_base_id')
          expect(json_response).to have_key('search_time_ms')
        end

        it 'each result has required fields' do
          subject
          next if json_response['results'].empty?

          result = json_response['results'].first
          expect(result).to have_key('rank')
          expect(result).to have_key('chunk_id')
          expect(result).to have_key('content')
          expect(result).to have_key('similarity_score')
          expect(result).to have_key('document_id')
          expect(result).to have_key('document_title')
        end

        include_examples 'returns request_id in response'
      end
    end

    describe 'POST /api/v1/knowledge_bases/:id/ask' do
      before do
        allow_any_instance_of(LlmService).to receive(:answer_question)
          .and_return({ answer: 'Test answer', model: 'test-model' })
      end

      context 'successful question' do
        subject do
          post "/api/v1/knowledge_bases/#{knowledge_base.id}/ask",
               params: { question: 'What is this?' },
               headers: headers
        end

        it 'returns 200 status' do
          subject
          expect(response).to have_http_status(:ok)
        end

        it 'returns answer' do
          subject
          expect(json_response).to have_key('answer')
          expect(json_response['answer']).to be_a(String)
        end

        it 'returns question echo' do
          subject
          expect(json_response).to have_key('question')
        end

        it 'returns sources array' do
          subject
          expect(json_response).to have_key('sources')
          expect(json_response['sources']).to be_an(Array)
        end

        it 'returns model information' do
          subject
          expect(json_response).to have_key('model')
        end

        it 'returns processing metadata' do
          subject
          expect(json_response).to have_key('chunks_used')
          expect(json_response).to have_key('total_chunks_searched')
          expect(json_response).to have_key('processing_time_ms')
        end

        include_examples 'returns request_id in response'
      end
    end
  end

  describe 'Health Endpoints Contract' do
    describe 'GET /api/v1/health' do
      before do
        allow_any_instance_of(Clients::OllamaClient).to receive(:health_check).and_return(true)
        allow_any_instance_of(Clients::OllamaClient).to receive(:list_models).and_return([])
      end

      subject { get '/api/v1/health' }

      it 'returns status field' do
        subject
        expect(json_response).to have_key('status')
        expect(json_response['status']).to be_in(%w[ok degraded])
      end

      it 'returns timestamp' do
        subject
        expect(json_response).to have_key('timestamp')
      end

      it 'returns services status' do
        subject
        expect(json_response).to have_key('services')
        services = json_response['services']

        expect(services).to have_key('api')
        expect(services).to have_key('database')
        expect(services).to have_key('ollama')
      end

      it 'returns version information' do
        subject
        expect(json_response).to have_key('version')
        expect(json_response['version']).to have_key('ruby')
        expect(json_response['version']).to have_key('rails')
      end
    end

    describe 'GET /api/v1/health/liveness' do
      subject { get '/api/v1/health/liveness' }

      it 'returns 200 status' do
        subject
        expect(response).to have_http_status(:ok)
      end

      it 'returns status ok' do
        subject
        expect(json_response['status']).to eq('ok')
      end
    end

    describe 'GET /api/v1/health/readiness' do
      subject { get '/api/v1/health/readiness' }

      it 'returns status field' do
        subject
        expect(json_response).to have_key('status')
      end
    end
  end
end
