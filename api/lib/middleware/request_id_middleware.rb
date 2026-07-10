# frozen_string_literal: true

module Middleware
  # Middleware to ensure every request has a unique request ID for tracing
  # This enables distributed tracing and correlating logs across services
  class RequestIdMiddleware
    REQUEST_ID_HEADER = "X-Request-Id"
    REQUEST_ID_PATTERN = /\A[a-f0-9\-]{36}\z/i

    def initialize(app)
      @app = app
    end

    def call(env)
      request_id = extract_or_generate_request_id(env)

      # Store in RequestStore for access throughout the request
      RequestStore.store[:request_id] = request_id

      # Add to env for Rails and other middleware
      env["action_dispatch.request_id"] = request_id
      env["HTTP_X_REQUEST_ID"] = request_id

      status, headers, body = @app.call(env)

      # Ensure response includes request ID
      headers[REQUEST_ID_HEADER] = request_id

      [ status, headers, body ]
    end

    private

    def extract_or_generate_request_id(env)
      # Accept request ID from client if valid UUID format (for tracing)
      incoming_id = env["HTTP_X_REQUEST_ID"]

      if incoming_id && incoming_id.match?(REQUEST_ID_PATTERN)
        incoming_id
      else
        SecureRandom.uuid
      end
    end
  end
end
