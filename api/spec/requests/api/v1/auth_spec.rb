require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request do
  describe 'POST /api/v1/auth/register' do
    let(:valid_params) do
      {
        email: 'test@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      }
    end

    context 'with valid parameters' do
      it 'creates a new user and returns token' do
        expect {
          post '/api/v1/auth/register', params: valid_params
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['token']).to be_present
        expect(json_response['user']['email']).to eq('test@example.com')
        expect(json_response['message']).to eq('User created successfully')
      end

      it 'returns user without password_digest' do
        post '/api/v1/auth/register', params: valid_params

        expect(json_response['user']).not_to have_key('password_digest')
        expect(json_response['user']).not_to have_key('password')
      end
    end

    context 'with invalid parameters' do
      it 'returns errors for missing email' do
        post '/api/v1/auth/register', params: { password: 'password123' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include("Email can't be blank")
      end

      it 'returns errors for invalid email format' do
        post '/api/v1/auth/register', params: { email: 'invalid', password: 'password123' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('Email is invalid')
      end

      it 'returns errors for short password' do
        post '/api/v1/auth/register', params: { email: 'test@example.com', password: '12345' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('Password is too short (minimum is 6 characters)')
      end

      it 'returns errors for duplicate email' do
        create(:user, email: 'test@example.com')
        post '/api/v1/auth/register', params: valid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('Email has already been taken')
      end

      it 'handles case-insensitive email uniqueness' do
        create(:user, email: 'test@example.com')
        post '/api/v1/auth/register', params: valid_params.merge(email: 'TEST@EXAMPLE.COM')

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('Email has already been taken')
      end
    end
  end

  describe 'POST /api/v1/auth/login' do
    let!(:user) { create(:user, email: 'test@example.com', password: 'password123') }

    context 'with a malformed JSON body' do
      it 'returns 400, not 500' do
        post '/api/v1/auth/login',
             params: '{bad',
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']).to eq('malformed_request')
      end
    end

    context 'with valid credentials' do
      it 'returns a token' do
        post '/api/v1/auth/login', params: { email: 'test@example.com', password: 'password123' }

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
        expect(json_response['user']['email']).to eq('test@example.com')
        expect(json_response['message']).to eq('Login successful')
      end

      it 'handles case-insensitive email login' do
        post '/api/v1/auth/login', params: { email: 'TEST@EXAMPLE.COM', password: 'password123' }

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
      end

      it 'returns a valid JWT token' do
        post '/api/v1/auth/login', params: { email: 'test@example.com', password: 'password123' }

        token = json_response['token']
        decoded = JwtService.decode(token)
        expect(decoded[:user_id]).to eq(user.id)
      end
    end

    context 'with invalid credentials' do
      it 'returns unauthorized for wrong password' do
        post '/api/v1/auth/login', params: { email: 'test@example.com', password: 'wrongpassword' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to eq('Invalid email or password')
      end

      it 'returns unauthorized for non-existent user' do
        post '/api/v1/auth/login', params: { email: 'nonexistent@example.com', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to eq('Invalid email or password')
      end

      it 'returns unauthorized for missing email' do
        post '/api/v1/auth/login', params: { password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for missing password' do
        post '/api/v1/auth/login', params: { email: 'test@example.com' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/auth/logout' do
    it 'returns success message' do
      delete '/api/v1/auth/logout'

      expect(response).to have_http_status(:ok)
      expect(json_response['message']).to eq('Logged out successfully')
    end
  end
end
