# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Authentication API', type: :request do
  path '/api/v1/auth/register' do
    post 'Register a new user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security []

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email, example: 'user@example.com' },
          password: { type: :string, minLength: 6, example: 'password123' },
          password_confirmation: { type: :string, example: 'password123' }
        },
        required: %w[email password password_confirmation]
      }

      response '201', 'User registered successfully' do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'User created successfully' },
                 user: { '$ref' => '#/components/schemas/User' },
                 token: { type: :string, description: 'JWT token' },
                 request_id: { type: :string, format: :uuid }
               },
               required: %w[message user token]

        let(:body) { { email: 'newuser@example.com', password: 'password123', password_confirmation: 'password123' } }

        run_test!
      end

      response '422', 'Validation failed' do
        schema '$ref' => '#/components/schemas/Error'

        let(:body) { { email: 'invalid', password: '123' } }

        run_test!
      end
    end
  end

  path '/api/v1/auth/login' do
    post 'Login user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security []

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email, example: 'user@example.com' },
          password: { type: :string, example: 'password123' }
        },
        required: %w[email password]
      }

      response '200', 'Login successful' do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Login successful' },
                 user: { '$ref' => '#/components/schemas/User' },
                 token: { type: :string, description: 'JWT token' },
                 request_id: { type: :string, format: :uuid }
               },
               required: %w[message user token]

        let!(:user) { create(:user, email: 'test@example.com', password: 'password123') }
        let(:body) { { email: 'test@example.com', password: 'password123' } }

        run_test!
      end

      response '401', 'Invalid credentials' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'Invalid email or password' }
               }

        let(:body) { { email: 'wrong@example.com', password: 'wrongpassword' } }

        run_test!
      end
    end
  end

  path '/api/v1/auth/logout' do
    delete 'Logout user' do
      tags 'Authentication'
      produces 'application/json'
      security []

      response '200', 'Logged out successfully' do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Logged out successfully' }
               }

        run_test!
      end
    end
  end
end
