# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::HealthController, type: :request do
  let(:base_url) { 'http://localhost:11434' }

  describe 'GET /api/v1/health' do
    context 'when all services are healthy' do
      before do
        stub_request(:get, "#{base_url}/api/tags")
          .to_return(
            status: 200,
            body: {
              models: [
                { name: 'nomic-embed-text' },
                { name: 'llama3.2:3b' }
              ]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns 200 OK with service status' do
        get '/api/v1/health'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['status']).to eq('ok')
        expect(json['services']['api']['status']).to eq('ok')
        expect(json['services']['database']['status']).to eq('ok')
        expect(json['services']['ollama']['status']).to eq('ok')
      end

      it 'includes Ollama models list' do
        get '/api/v1/health'

        json = JSON.parse(response.body)
        expect(json['ollama_models']).to include('nomic-embed-text', 'llama3.2:3b')
      end

      it 'includes version information' do
        get '/api/v1/health'

        json = JSON.parse(response.body)
        expect(json['version']['ruby']).to eq(RUBY_VERSION)
        expect(json['version']['rails']).to eq(Rails.version)
      end

      it 'includes timestamp' do
        get '/api/v1/health'

        json = JSON.parse(response.body)
        expect(json['timestamp']).to be_present
      end
    end

    context 'when Ollama is unavailable' do
      before do
        stub_request(:get, "#{base_url}/api/tags")
          .to_raise(Errno::ECONNREFUSED)
      end

      it 'returns 503 with degraded status' do
        get '/api/v1/health'

        expect(response).to have_http_status(:service_unavailable)
        json = JSON.parse(response.body)

        expect(json['status']).to eq('degraded')
        expect(json['services']['ollama']['status']).to eq('error')
      end
    end

    it 'does not require authentication' do
      stub_request(:get, "#{base_url}/api/tags")
        .to_return(status: 200, body: { models: [] }.to_json)

      get '/api/v1/health'

      expect(response).not_to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/health/liveness' do
    it 'returns 200 OK' do
      get '/api/v1/health/liveness'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['status']).to eq('ok')
      expect(json['timestamp']).to be_present
    end

    it 'does not require authentication' do
      get '/api/v1/health/liveness'

      expect(response).not_to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/health/readiness' do
    context 'when database is ready' do
      it 'returns 200 OK with ready status' do
        get '/api/v1/health/readiness'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['status']).to eq('ready')
      end
    end

    context 'when database is unavailable' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(ActiveRecord::ConnectionNotEstablished)
      end

      it 'returns 503 with not_ready status' do
        get '/api/v1/health/readiness'

        expect(response).to have_http_status(:service_unavailable)
        json = JSON.parse(response.body)

        expect(json['status']).to eq('not_ready')
        expect(json['reason']).to eq('database_unavailable')
      end
    end

    it 'does not require authentication' do
      get '/api/v1/health/readiness'

      expect(response).not_to have_http_status(:unauthorized)
    end
  end
end
