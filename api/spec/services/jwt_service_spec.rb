require 'rails_helper'

RSpec.describe JwtService do
  describe '.encode' do
    it 'returns a valid JWT token' do
      payload = { user_id: 1 }
      token = described_class.encode(payload)

      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3)
    end

    it 'includes expiration time in payload' do
      payload = { user_id: 1 }
      token = described_class.encode(payload)
      decoded = JWT.decode(token, JwtService::SECRET_KEY, true, { algorithm: JwtService::ALGORITHM }).first

      expect(decoded['exp']).to be_present
      expect(decoded['iat']).to be_present
    end
  end

  describe '.decode' do
    it 'decodes a valid token' do
      payload = { user_id: 1 }
      token = described_class.encode(payload)
      decoded = described_class.decode(token)

      expect(decoded[:user_id]).to eq(1)
    end

    it 'returns HashWithIndifferentAccess' do
      payload = { user_id: 1 }
      token = described_class.encode(payload)
      decoded = described_class.decode(token)

      expect(decoded).to be_a(HashWithIndifferentAccess)
      expect(decoded['user_id']).to eq(1)
      expect(decoded[:user_id]).to eq(1)
    end

    it 'raises error for invalid token' do
      expect {
        described_class.decode('invalid.token.here')
      }.to raise_error(JwtService::AuthenticationError)
    end

    it 'raises error for malformed token' do
      expect {
        described_class.decode('not-a-jwt')
      }.to raise_error(JwtService::AuthenticationError)
    end

    it 'raises error for expired token' do
      payload = { user_id: 1, exp: 1.hour.ago.to_i }
      token = JWT.encode(payload, JwtService::SECRET_KEY, JwtService::ALGORITHM)

      expect {
        described_class.decode(token)
      }.to raise_error(JwtService::AuthenticationError, 'Token has expired')
    end

    it 'raises error for token with wrong secret' do
      payload = { user_id: 1, exp: 1.hour.from_now.to_i }
      token = JWT.encode(payload, 'wrong-secret', JwtService::ALGORITHM)

      expect {
        described_class.decode(token)
      }.to raise_error(JwtService::AuthenticationError)
    end
  end
end
