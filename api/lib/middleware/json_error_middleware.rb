# frozen_string_literal: true

module Middleware
  # Middleware to catch low-level errors and return proper JSON responses
  # This handles errors that occur before reaching the Rails error handlers
  class JsonErrorMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue ActionDispatch::Http::Parameters::ParseError => e
      json_error_response(
        status: 400,
        error: "Invalid JSON",
        message: "The request body contains malformed JSON",
        details: e.message.to_s.truncate(200),
        request_id: env["action_dispatch.request_id"]
      )
    rescue ActionController::BadRequest => e
      json_error_response(
        status: 400,
        error: "Bad Request",
        message: e.message.to_s.truncate(200),
        request_id: env["action_dispatch.request_id"]
      )
    end

    private

    def json_error_response(status:, error:, message:, request_id: nil, details: nil)
      body = {
        error: error,
        message: message,
        request_id: request_id
      }
      body[:details] = details if details

      [
        status,
        {
          "Content-Type" => "application/json",
          "X-Request-Id" => request_id || SecureRandom.uuid
        },
        [ body.to_json ]
      ]
    end
  end
end
