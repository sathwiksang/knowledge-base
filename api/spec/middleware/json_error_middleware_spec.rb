# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Middleware::JsonErrorMiddleware do
  let(:app) { ->(env) { [200, { "Content-Type" => "application/json" }, ['{"ok":true}']] } }
  let(:middleware) { described_class.new(app) }

  describe '#call' do
    it 'passes requests through to the app when no error' do
      status, _headers, body = middleware.call({})
      expect(status).to eq(200)
      expect(body.first).to eq('{"ok":true}')
    end

    context 'when ActionDispatch::Http::Parameters::ParseError is raised' do
      let(:app) do
        lambda { |_env| raise ActionDispatch::Http::Parameters::ParseError.new("unexpected token") }
      end

      it 'returns 400 status' do
        status, _headers, _body = middleware.call({ "action_dispatch.request_id" => "req-123" })
        expect(status).to eq(400)
      end

      it 'returns JSON content type' do
        _status, headers, _body = middleware.call({ "action_dispatch.request_id" => "req-123" })
        expect(headers["Content-Type"]).to eq("application/json")
      end

      it 'returns error body with Invalid JSON message' do
        _status, _headers, body = middleware.call({ "action_dispatch.request_id" => "req-123" })
        parsed = JSON.parse(body.first)
        expect(parsed["error"]).to eq("Invalid JSON")
        expect(parsed["message"]).to eq("The request body contains malformed JSON")
      end

      it 'includes request_id from env' do
        _status, headers, body = middleware.call({ "action_dispatch.request_id" => "req-123" })
        parsed = JSON.parse(body.first)
        expect(parsed["request_id"]).to eq("req-123")
        expect(headers["X-Request-Id"]).to eq("req-123")
      end

      it 'includes truncated details' do
        long_message = "a" * 300
        app_with_long_error = lambda { |_env|
          raise ActionDispatch::Http::Parameters::ParseError.new(long_message)
        }
        mw = described_class.new(app_with_long_error)
        _status, _headers, body = mw.call({})
        parsed = JSON.parse(body.first)
        expect(parsed["details"].length).to be <= 200
      end
    end

    context 'when ActionController::BadRequest is raised' do
      let(:app) do
        lambda { |_env| raise ActionController::BadRequest.new("bad param") }
      end

      it 'returns 400 status' do
        status, _headers, _body = middleware.call({})
        expect(status).to eq(400)
      end

      it 'returns Bad Request error' do
        _status, _headers, body = middleware.call({})
        parsed = JSON.parse(body.first)
        expect(parsed["error"]).to eq("Bad Request")
      end

      it 'truncates long messages' do
        long_app = lambda { |_env|
          raise ActionController::BadRequest.new("x" * 300)
        }
        mw = described_class.new(long_app)
        _status, _headers, body = mw.call({})
        parsed = JSON.parse(body.first)
        expect(parsed["message"].length).to be <= 200
      end
    end

    context 'when request_id is nil' do
      let(:app) do
        lambda { |_env| raise ActionDispatch::Http::Parameters::ParseError.new("bad json") }
      end

      it 'generates a UUID for X-Request-Id header' do
        _status, headers, _body = middleware.call({})
        expect(headers["X-Request-Id"]).to match(/\A[0-9a-f-]{36}\z/)
      end
    end
  end
end
