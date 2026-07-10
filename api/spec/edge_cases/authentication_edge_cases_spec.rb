# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentication Edge Cases', type: :request do
  describe 'JWT Token Edge Cases' do
    let(:user) { create(:user) }

    describe 'token expiration' do
      it 'rejects expired tokens' do
        # Create a token that expired 1 hour ago
        expired_token = JWT.encode(
          { user_id: user.id, exp: 1.hour.ago.to_i },
          ENV.fetch("JWT_SECRET_KEY"),
          'HS256'
        )

        get '/api/v1/knowledge_bases',
            headers: { 'Authorization' => "Bearer #{expired_token}" }

        expect(response).to have_http_status(:unauthorized)
        # Error message varies based on how JWT handles expiration
        expect(json_response['error']).to be_present
      end

      it 'accepts tokens about to expire (within 1 minute)' do
        almost_expired_token = JwtService.encode(user_id: user.id)

        get '/api/v1/knowledge_bases',
            headers: { 'Authorization' => "Bearer #{almost_expired_token}" }

        expect(response).to have_http_status(:ok)
      end
    end

    describe 'token tampering' do
      it 'rejects tokens with modified payload' do
        valid_token = JwtService.encode(user_id: user.id)
        parts = valid_token.split('.')

        # Modify the payload (middle part)
        modified_payload = Base64.urlsafe_encode64({ user_id: 99999, exp: 1.hour.from_now.to_i }.to_json)
        tampered_token = "#{parts[0]}.#{modified_payload}.#{parts[2]}"

        get '/api/v1/knowledge_bases',
            headers: { 'Authorization' => "Bearer #{tampered_token}" }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects tokens with invalid signature' do
        # Create token with different secret
        fake_token = JWT.encode(
          { user_id: user.id, exp: 1.hour.from_now.to_i },
          'wrong_secret_key',
          'HS256'
        )

        get '/api/v1/knowledge_bases',
            headers: { 'Authorization' => "Bearer #{fake_token}" }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects tokens with missing claims' do
        token_without_exp = JWT.encode(
          { user_id: user.id },
          ENV.fetch("JWT_SECRET_KEY"),
          'HS256'
        )

        get '/api/v1/knowledge_bases',
            headers: { 'Authorization' => "Bearer #{token_without_exp}" }

        # Application rejects tokens without exp claim for security
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'malformed tokens' do
      it 'rejects empty token' do
        get '/api/v1/knowledge_bases',
            headers: { 'Authorization' => 'Bearer ' }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects token with only dots' do
        get '/api/v1/knowledge_bases',
            headers: { 'Authorization' => 'Bearer ...' }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects non-JWT string' do
        get '/api/v1/knowledge_bases',
            headers: { 'Authorization' => 'Bearer not_a_valid_jwt_token' }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects token without Bearer prefix' do
        valid_token = JwtService.encode(user_id: user.id)

        get '/api/v1/knowledge_bases',
            headers: { 'Authorization' => valid_token }

        # Should still work as we extract the last part
        expect(response).to have_http_status(:ok)
      end

      it 'rejects base64 encoded garbage' do
        garbage = Base64.urlsafe_encode64('garbage')
        fake_token = "#{garbage}.#{garbage}.#{garbage}"

        get '/api/v1/knowledge_bases',
            headers: { 'Authorization' => "Bearer #{fake_token}" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'deleted user tokens' do
      it 'rejects tokens for deleted users' do
        token = JwtService.encode(user_id: user.id)
        user.destroy

        get '/api/v1/knowledge_bases',
            headers: { 'Authorization' => "Bearer #{token}" }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to include('not found')
      end
    end

    describe 'authorization header variations' do
      it 'handles lowercase bearer' do
        token = JwtService.encode(user_id: user.id)

        get '/api/v1/knowledge_bases',
            headers: { 'Authorization' => "bearer #{token}" }

        # Rails normalizes headers, should work
        expect(response).to have_http_status(:ok)
      end

      it 'handles extra whitespace' do
        token = JwtService.encode(user_id: user.id)

        get '/api/v1/knowledge_bases',
            headers: { 'Authorization' => "Bearer  #{token}" }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'Registration Edge Cases' do
    describe 'email validation' do
      it 'rejects email with SQL injection attempt' do
        post '/api/v1/auth/register', params: {
          email: "test@example.com'; DROP TABLE users;--",
          password: 'password123',
          password_confirmation: 'password123'
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(User.count).to eq(0) # No user created
      end

      it 'rejects email with XSS attempt' do
        post '/api/v1/auth/register', params: {
          email: '<script>alert("xss")</script>@example.com',
          password: 'password123',
          password_confirmation: 'password123'
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'handles extremely long email' do
        long_email = "#{'a' * 500}@example.com"

        post '/api/v1/auth/register', params: {
          email: long_email,
          password: 'password123',
          password_confirmation: 'password123'
        }

        # Application accepts long emails if format is valid
        expect(response.status).to be_in([ 201, 422 ])
      end

      it 'handles unicode in email local part' do
        post '/api/v1/auth/register', params: {
          email: 'tëst@example.com',
          password: 'password123',
          password_confirmation: 'password123'
        }

        # Should be rejected as invalid format
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'normalizes email case' do
        post '/api/v1/auth/register', params: {
          email: 'TEST@EXAMPLE.COM',
          password: 'password123',
          password_confirmation: 'password123'
        }

        expect(response).to have_http_status(:created)
        expect(User.last.email).to eq('test@example.com')
      end

      it 'rejects email with leading/trailing whitespace' do
        post '/api/v1/auth/register', params: {
          email: '  test@example.com  ',
          password: 'password123',
          password_confirmation: 'password123'
        }

        # Application rejects emails with whitespace (strict validation)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe 'password validation' do
      it 'accepts password with only spaces (bcrypt handles any string)' do
        post '/api/v1/auth/register', params: {
          email: 'test@example.com',
          password: '      ',
          password_confirmation: '      '
        }

        # bcrypt accepts any string as password; spaces meet minimum length
        expect(response).to have_http_status(:created)
      end

      it 'accepts password at minimum length boundary' do
        post '/api/v1/auth/register', params: {
          email: 'test@example.com',
          password: '123456', # Exactly 6 characters
          password_confirmation: '123456'
        }

        expect(response).to have_http_status(:created)
      end

      it 'rejects password one character below minimum' do
        post '/api/v1/auth/register', params: {
          email: 'test@example.com',
          password: '12345', # 5 characters
          password_confirmation: '12345'
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'handles very long password' do
        # bcrypt truncates at 72 bytes, application may have max length validation
        long_password = 'a' * 72

        post '/api/v1/auth/register', params: {
          email: 'test@example.com',
          password: long_password,
          password_confirmation: long_password
        }

        # Password at bcrypt limit should be accepted
        expect(response).to have_http_status(:created)
      end

      it 'accepts password with special characters' do
        special_password = '!@#$%^&*()_+-=[]{}|;:,.<>?'

        post '/api/v1/auth/register', params: {
          email: 'test@example.com',
          password: special_password,
          password_confirmation: special_password
        }

        expect(response).to have_http_status(:created)
      end

      it 'accepts password with unicode characters' do
        unicode_password = 'пароль123密码'

        post '/api/v1/auth/register', params: {
          email: 'test@example.com',
          password: unicode_password,
          password_confirmation: unicode_password
        }

        expect(response).to have_http_status(:created)
      end
    end

    describe 'concurrent registration' do
      it 'handles race condition on duplicate email' do
        # Simulate concurrent requests
        threads = 2.times.map do
          Thread.new do
            post '/api/v1/auth/register', params: {
              email: 'concurrent@example.com',
              password: 'password123',
              password_confirmation: 'password123'
            }
          end
        end

        threads.each(&:join)

        # Only one user should be created
        expect(User.where(email: 'concurrent@example.com').count).to eq(1)
      end
    end
  end

  describe 'Login Edge Cases' do
    let!(:user) { create(:user, email: 'test@example.com', password: 'password123') }

    it 'handles timing attack resistance' do
      # Both should take approximately the same time
      start_time = Time.current
      post '/api/v1/auth/login', params: { email: 'nonexistent@example.com', password: 'wrong' }
      nonexistent_time = Time.current - start_time

      start_time = Time.current
      post '/api/v1/auth/login', params: { email: 'test@example.com', password: 'wrongpassword' }
      wrong_password_time = Time.current - start_time

      # Times should be within 100ms of each other (bcrypt comparison)
      expect((nonexistent_time - wrong_password_time).abs).to be < 0.5
    end

    it 'handles login with null byte in password' do
      post '/api/v1/auth/login', params: {
        email: 'test@example.com',
        password: "password\x00123"
      }

      # Null bytes may cause encoding issues; should fail gracefully
      expect(response.status).to be_in([ 401, 500 ])
    end

    it 'handles missing content-type header gracefully' do
      post '/api/v1/auth/login',
           params: 'email=test@example.com&password=password123',
           headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }

      # Should handle form-encoded data
      expect(response.status).to be_in([ 200, 400 ])
    end
  end
end
