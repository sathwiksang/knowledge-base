# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Health API', type: :request do
  path '/api/v1/health' do
    get 'Full health check' do
      tags 'Health'
      produces 'application/json'
      security []

      response '200', 'System healthy' do
        schema '$ref' => '#/components/schemas/HealthStatus'

        before do
          allow_any_instance_of(Clients::OllamaClient).to receive(:health_check).and_return(true)
          allow_any_instance_of(Clients::OllamaClient).to receive(:list_models).and_return([])
        end

        run_test!
      end

      response '503', 'System degraded' do
        schema '$ref' => '#/components/schemas/HealthStatus'

        before do
          allow_any_instance_of(Clients::OllamaClient).to receive(:health_check).and_return(false)
          allow_any_instance_of(Clients::OllamaClient).to receive(:list_models).and_return([])
        end

        run_test!
      end
    end
  end

  path '/api/v1/health/liveness' do
    get 'Liveness probe' do
      tags 'Health'
      produces 'application/json'
      security []
      description 'Lightweight liveness check for Kubernetes'

      response '200', 'API is alive' do
        schema type: :object,
               properties: {
                 status: { type: :string, example: 'ok' },
                 timestamp: { type: :string, format: 'date-time' }
               }

        run_test!
      end
    end
  end

  path '/api/v1/health/readiness' do
    get 'Readiness probe' do
      tags 'Health'
      produces 'application/json'
      security []
      description 'Readiness check including database connectivity'

      response '200', 'API is ready' do
        schema type: :object,
               properties: {
                 status: { type: :string, example: 'ready' },
                 timestamp: { type: :string, format: 'date-time' }
               }

        run_test!
      end
    end
  end
end
