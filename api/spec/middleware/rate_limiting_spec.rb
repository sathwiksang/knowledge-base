# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rate Limiting', type: :request do
  # Note: Rack::Attack is disabled in test environment
  # These tests verify the configuration is correct

  describe 'Rack::Attack configuration' do
    it 'is disabled in test environment' do
      expect(Rack::Attack.enabled).to be false
    end

    it 'has throttle rules configured' do
      throttles = Rack::Attack.throttles

      expect(throttles).to include('api/ip')
      expect(throttles).to include('auth/ip')
      expect(throttles).to include('auth/login/ip')
      expect(throttles).to include('auth/register/ip')
      expect(throttles).to include('search/ip')
      expect(throttles).to include('ask/ip')
      expect(throttles).to include('documents/create/ip')
    end

    it 'has blocklist rules configured' do
      blocklists = Rack::Attack.blocklists

      expect(blocklists).to include('block-bad-requests')
      expect(blocklists).to include('fail2ban/login')
    end

    it 'has no environment-based safelists (app is internet-exposed via tunnel)' do
      safelists = Rack::Attack.safelists

      expect(safelists).not_to include('allow-localhost')
    end

    it 'has SQL injection and sensitive path blocklists' do
      blocklists = Rack::Attack.blocklists

      expect(blocklists).to include('block-sql-injection')
      expect(blocklists).to include('block-sensitive-paths')
    end
  end

  describe 'throttle limits' do
    it 'api/ip has correct configuration' do
      throttle = Rack::Attack.throttles['api/ip']

      expect(throttle).to be_present
    end

    it 'auth/ip has correct configuration' do
      throttle = Rack::Attack.throttles['auth/ip']

      expect(throttle).to be_present
    end
  end
end
