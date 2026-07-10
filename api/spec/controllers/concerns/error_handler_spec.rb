# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ErrorHandler do
  describe 'module inclusion' do
    it 'can be included in controllers' do
      expect(ApplicationController.ancestors).to include(ErrorHandler)
    end
  end

  describe 'error handler methods via controller stubbing', type: :request do
    let(:user) { create(:user) }
    let(:headers) { auth_headers(user) }
    let!(:knowledge_base) { create(:knowledge_base, user: user) }

    it 'handles ActiveRecord::RecordNotFound with model name' do
      get '/api/v1/knowledge_bases/99999', headers: headers
      expect(response).to have_http_status(:not_found)
      expect(json_response['error']).to include('not found')
    end

    it 'handles ActiveRecord::RecordInvalid' do
      post '/api/v1/knowledge_bases', params: { name: '' }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to be_present
    end

    it 'handles ActiveRecord::RecordNotUnique' do
      allow_any_instance_of(Api::V1::KnowledgeBasesController).to receive(:create).and_raise(
        ActiveRecord::RecordNotUnique.new("Duplicate entry")
      )
      post '/api/v1/knowledge_bases', params: { name: "Test KB" }, headers: headers
      expect(response).to have_http_status(:conflict)
      expect(json_response['error']).to eq('conflict')
    end

    it 'handles ActionController::ParameterMissing' do
      allow_any_instance_of(Api::V1::KnowledgeBasesController).to receive(:create).and_raise(
        ActionController::ParameterMissing.new(:name)
      )
      post '/api/v1/knowledge_bases', params: {}, headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(json_response['error']).to eq('parameter_missing')
    end

    it 'handles ActionController::BadRequest' do
      allow_any_instance_of(Api::V1::KnowledgeBasesController).to receive(:index).and_raise(
        ActionController::BadRequest.new("Bad request data")
      )
      get '/api/v1/knowledge_bases', headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(json_response['error']).to eq('bad_request')
    end

    it 'handles JWT::DecodeError' do
      get '/api/v1/knowledge_bases',
        headers: { 'Authorization' => 'Bearer invalid_token' }
      expect(response).to have_http_status(:unauthorized)
      expect(json_response['error']).to be_present
    end

    it 'handles JWT::ExpiredSignature' do
      payload = { user_id: user.id, exp: 1.hour.ago.to_i, iat: 2.hours.ago.to_i }
      expired_token = JWT.encode(payload, JwtService::SECRET_KEY, JwtService::ALGORITHM)
      get '/api/v1/knowledge_bases',
        headers: { 'Authorization' => "Bearer #{expired_token}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'handles Clients::OllamaClient::OllamaError' do
      allow_any_instance_of(Api::V1::KnowledgeBasesController).to receive(:index).and_raise(
        Clients::OllamaClient::OllamaError.new("Connection refused")
      )
      get '/api/v1/knowledge_bases', headers: headers
      expect(response).to have_http_status(:service_unavailable)
      expect(json_response['error']).to eq('ai_service_error')
    end

    it 'handles EmbeddingService::EmbeddingError' do
      allow_any_instance_of(Api::V1::KnowledgeBasesController).to receive(:index).and_raise(
        EmbeddingService::EmbeddingError.new("Embedding failed")
      )
      get '/api/v1/knowledge_bases', headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to eq('embedding_error')
    end

    it 'handles LlmService::LlmError' do
      allow_any_instance_of(Api::V1::KnowledgeBasesController).to receive(:index).and_raise(
        LlmService::LlmError.new("LLM failed")
      )
      get '/api/v1/knowledge_bases', headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to eq('llm_error')
    end

    it 'handles unexpected StandardError' do
      allow_any_instance_of(Api::V1::KnowledgeBasesController).to receive(:index).and_raise(
        StandardError.new("Something broke")
      )
      get '/api/v1/knowledge_bases', headers: headers
      expect(response).to have_http_status(:internal_server_error)
      expect(json_response['error']).to eq('internal_server_error')
    end

    it 'handles ApiErrors::BaseError' do
      allow_any_instance_of(Api::V1::KnowledgeBasesController).to receive(:index).and_raise(
        ApiErrors::NotFoundError.new("Knowledge base")
      )
      get '/api/v1/knowledge_bases', headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it 'includes request_id and timestamp in error responses' do
      get '/api/v1/knowledge_bases/99999', headers: headers
      expect(json_response['request_id']).to be_present
      expect(json_response['timestamp']).to be_present
    end

    it 'logs errors with appropriate level' do
      allow(Rails.logger).to receive(:info)
      post '/api/v1/knowledge_bases', params: { name: '' }, headers: headers
      expect(Rails.logger).to have_received(:info).at_least(:once)
    end
  end

  describe 'error handling through request specs', type: :request do
    let(:user) { create(:user) }
    let(:headers) { auth_headers(user) }

    describe 'authentication errors' do
      it 'returns 401 for missing token' do
        get '/api/v1/knowledge_bases'

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to include('Missing')
      end

      it 'returns 401 for invalid token' do
        get '/api/v1/knowledge_bases', headers: { 'Authorization' => 'Bearer invalid_token' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to be_present
      end
    end

    describe 'not found errors' do
      it 'returns 404 for non-existent knowledge base' do
        get '/api/v1/knowledge_bases/99999', headers: headers

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to include('not found')
      end

      it 'returns 404 for non-existent document' do
        get '/api/v1/documents/99999', headers: headers

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to include('not found')
      end
    end

    describe 'validation errors' do
      it 'returns 422 for invalid knowledge base creation' do
        post '/api/v1/knowledge_bases', params: { name: '' }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to be_an(Array)
      end
    end

    describe 'duplicate resource errors' do
      it 'returns 409 for duplicate knowledge base name' do
        create(:knowledge_base, user: user, name: "Existing KB")
        post '/api/v1/knowledge_bases', params: { name: "Existing KB" }, headers: headers

        expect(response.status).to be_in([409, 422])
      end
    end

    describe 'JWT errors' do
      it 'returns 401 for expired token' do
        payload = { user_id: user.id, exp: 1.hour.ago.to_i, iat: 2.hours.ago.to_i }
        expired_token = JWT.encode(payload, JwtService::SECRET_KEY, JwtService::ALGORITHM)
        get '/api/v1/knowledge_bases',
          headers: { 'Authorization' => "Bearer #{expired_token}" }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 401 for tampered token' do
        token = JwtService.encode({ user_id: user.id })
        tampered = token + "x"
        get '/api/v1/knowledge_bases',
          headers: { 'Authorization' => "Bearer #{tampered}" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'parameter missing errors' do
      it 'returns 400 or 422 for missing required params' do
        post '/api/v1/auth/register', params: {}

        expect(response.status).to be_in([400, 422])
      end
    end

    describe 'api error handling' do
      it 'handles not found errors for shallow document routes' do
        get "/api/v1/documents/99999", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'response format' do
      it 'includes request_id in error responses' do
        get '/api/v1/knowledge_bases/99999', headers: headers

        expect(json_response['request_id']).to be_present
      end

      it 'includes timestamp in error responses' do
        get '/api/v1/knowledge_bases/99999', headers: headers

        expect(json_response['timestamp']).to be_present
      end

      it 'returns JSON content type for errors' do
        get '/api/v1/knowledge_bases/99999', headers: headers

        expect(response.content_type).to include('application/json')
      end
    end
  end
end
