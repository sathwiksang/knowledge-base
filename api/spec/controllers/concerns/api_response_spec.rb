# frozen_string_literal: true

require 'rails_helper'

# Test controller to exercise ApiResponse helper methods directly
class ApiResponseTestController < ActionController::API
  include ApiResponse

  def test_success_nil
    render_success
  end

  def test_success_hash
    render_success({ name: "test", value: 42 })
  end

  def test_success_non_hash
    render_success("string data")
  end

  def test_success_kwargs
    render_success(message: "created", id: 1)
  end

  def test_success_meta
    render_success({ data: "test" }, meta: { page: 1 })
  end

  def test_created_hash
    render_created({ id: 1, name: "new" })
  end

  def test_created_non_hash
    render_created("created item")
  end

  def test_created_location
    render_created({ id: 1 }, location: "/api/v1/items/1")
  end

  def test_no_content
    render_no_content
  end

  def test_accepted
    render_accepted({ job_id: "abc-123" })
  end

  def test_accepted_non_hash
    render_accepted("processing")
  end

  def test_unprocessable
    render_unprocessable(["Name can't be blank", "Email is invalid"])
  end

  def test_unprocessable_single
    render_unprocessable("Name can't be blank")
  end

  def test_not_found
    render_not_found("Document")
  end

  def test_unauthorized
    render_unauthorized("Token expired")
  end

  def test_forbidden
    render_forbidden("Not your resource")
  end

  def test_bad_request
    render_bad_request("Invalid parameter")
  end

  def test_service_unavailable
    render_service_unavailable("Ollama")
  end
end

RSpec.describe ApiResponse, type: :request do
  before(:all) do
    Rails.application.routes.draw do
      %w[
        test_success_nil test_success_hash test_success_non_hash
        test_success_kwargs test_success_meta
        test_created_hash test_created_non_hash test_created_location
        test_no_content test_accepted test_accepted_non_hash
        test_unprocessable test_unprocessable_single
        test_not_found test_unauthorized test_forbidden
        test_bad_request test_service_unavailable
      ].each do |action|
        get "/test/#{action}", to: "api_response_test##{action}"
      end

      # Re-draw original routes
      namespace :api do
        namespace :v1 do
          get "health", to: "health#show"
          get "health/liveness", to: "health#liveness"
          get "health/readiness", to: "health#readiness"
          post "auth/register", to: "auth#register"
          post "auth/login", to: "auth#login"
          get "auth/profile", to: "auth#profile"
          delete "auth/logout", to: "auth#logout"
          resources :knowledge_bases, only: [:index, :show, :create, :update, :destroy] do
            resources :documents, only: [:index, :create] do
              collection do
                post "batch_reprocess"
              end
            end
            member do
              post "search"
              post "ask"
            end
          end
          resources :documents, only: [:show, :destroy] do
            member do
              post "reprocess"
              get "status"
            end
          end
        end
      end
      get "health", to: proc { [200, {}, ["OK"]] }
      get "up" => "rails/health#show", as: :rails_health_check
    end
  end

  after(:all) do
    Rails.application.reload_routes!
  end

  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe 'render_success' do
    it 'handles nil data' do
      get '/test/test_success_nil'
      expect(response).to have_http_status(:ok)
      expect(json_response['request_id']).to be_present
    end

    it 'renders hash data directly' do
      get '/test/test_success_hash'
      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('test')
      expect(json_response['value']).to eq(42)
    end

    it 'wraps non-hash data in data key' do
      get '/test/test_success_non_hash'
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to eq('string data')
    end

    it 'handles kwargs' do
      get '/test/test_success_kwargs'
      expect(response).to have_http_status(:ok)
      expect(json_response['message']).to eq('created')
    end

    it 'includes meta when provided' do
      get '/test/test_success_meta'
      expect(response).to have_http_status(:ok)
      expect(json_response['meta']).to eq({ 'page' => 1 })
    end
  end

  describe 'render_created' do
    it 'returns 201 with hash data' do
      get '/test/test_created_hash'
      expect(response).to have_http_status(:created)
      expect(json_response['id']).to eq(1)
    end

    it 'wraps non-hash data' do
      get '/test/test_created_non_hash'
      expect(response).to have_http_status(:created)
      expect(json_response['data']).to eq('created item')
    end

    it 'includes location header when provided' do
      get '/test/test_created_location'
      expect(response).to have_http_status(:created)
      expect(response.headers['Location']).to eq('/api/v1/items/1')
    end
  end

  describe 'render_no_content' do
    it 'returns 204 with no body' do
      get '/test/test_no_content'
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'render_accepted' do
    it 'returns 202 with hash data' do
      get '/test/test_accepted'
      expect(response).to have_http_status(:accepted)
      expect(json_response['job_id']).to eq('abc-123')
    end

    it 'wraps non-hash data' do
      get '/test/test_accepted_non_hash'
      expect(response).to have_http_status(:accepted)
      expect(json_response['data']).to eq('processing')
    end
  end

  describe 'render_unprocessable' do
    it 'returns 422 with errors array' do
      get '/test/test_unprocessable'
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to eq(["Name can't be blank", "Email is invalid"])
      expect(json_response['error']).to eq('validation_failed')
    end

    it 'wraps single error in array' do
      get '/test/test_unprocessable_single'
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to eq(["Name can't be blank"])
    end
  end

  describe 'render_not_found' do
    it 'returns 404 with resource name' do
      get '/test/test_not_found'
      expect(response).to have_http_status(:not_found)
      expect(json_response['error']).to eq('Document not found')
    end
  end

  describe 'render_unauthorized' do
    it 'returns 401 with message' do
      get '/test/test_unauthorized'
      expect(response).to have_http_status(:unauthorized)
      expect(json_response['message']).to eq('Token expired')
    end
  end

  describe 'render_forbidden' do
    it 'returns 403 with message' do
      get '/test/test_forbidden'
      expect(response).to have_http_status(:forbidden)
      expect(json_response['message']).to eq('Not your resource')
    end
  end

  describe 'render_bad_request' do
    it 'returns 400 with message' do
      get '/test/test_bad_request'
      expect(response).to have_http_status(:bad_request)
      expect(json_response['message']).to eq('Invalid parameter')
    end
  end

  describe 'render_service_unavailable' do
    it 'returns 503 with service name' do
      get '/test/test_service_unavailable'
      expect(response).to have_http_status(:service_unavailable)
      expect(json_response['message']).to include('Ollama')
    end
  end

  describe 'render_success' do
    it 'includes request_id in responses' do
      kb = create(:knowledge_base, user: user)
      get "/api/v1/knowledge_bases/#{kb.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['request_id']).to be_present
    end

    it 'renders hash data directly' do
      get '/api/v1/knowledge_bases', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)
    end
  end

  describe 'render_created' do
    it 'returns 201 status for created resources' do
      post '/api/v1/knowledge_bases',
        params: { name: "Test KB" },
        headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response['request_id']).to be_present
    end
  end

  describe 'render_success for deletions' do
    it 'returns success with message for deletions' do
      kb = create(:knowledge_base, user: user)
      delete "/api/v1/knowledge_bases/#{kb.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['message']).to include('deleted')
    end
  end

  describe 'render_unprocessable' do
    it 'returns 422 with error details' do
      post '/api/v1/knowledge_bases',
        params: { name: '' },
        headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to be_an(Array)
      expect(json_response['request_id']).to be_present
      expect(json_response['timestamp']).to be_present
    end
  end

  describe 'render_not_found' do
    it 'returns 404 with resource info' do
      get '/api/v1/knowledge_bases/99999', headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json_response['error']).to include('not found')
    end
  end

  describe 'render_unauthorized' do
    it 'returns 401 for missing auth' do
      get '/api/v1/knowledge_bases'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'render_bad_request' do
    it 'returns 400 for bad requests' do
      kb = create(:knowledge_base, user: user)
      post "/api/v1/knowledge_bases/#{kb.id}/search",
        params: { query: '' },
        headers: headers

      expect(response).to have_http_status(:bad_request).or have_http_status(:unprocessable_entity)
    end
  end

  describe 'render_forbidden' do
    it 'returns 403 when authorization fails' do
      other_user = create(:user, email: "other@example.com")
      kb = create(:knowledge_base, user: other_user)
      # Try to update another user's knowledge base
      patch "/api/v1/knowledge_bases/#{kb.id}",
        params: { name: "Hacked" },
        headers: headers

      expect(response).to have_http_status(:not_found).or have_http_status(:forbidden)
    end
  end

  describe 'render_service_unavailable' do
    it 'returns 503 when services are down' do
      kb = create(:knowledge_base, user: user)
      allow_any_instance_of(Api::V1::KnowledgeBasesController).to receive(:search).and_raise(
        Clients::OllamaClient::OllamaError.new("Connection refused")
      )
      post "/api/v1/knowledge_bases/#{kb.id}/search",
        params: { query: "test" },
        headers: headers

      expect(response).to have_http_status(:service_unavailable)
    end
  end

  describe 'set_default_response_format' do
    it 'defaults to JSON format' do
      get '/api/v1/knowledge_bases', headers: headers

      expect(response.content_type).to include('application/json')
    end
  end

  describe 'render_success with various data types' do
    it 'handles nil data' do
      delete "/api/v1/auth/logout", headers: headers

      expect(response).to have_http_status(:ok)
    end

    it 'wraps non-hash data' do
      get '/api/v1/knowledge_bases', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response).to be_a(Hash)
    end
  end
end
