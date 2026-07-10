# frozen_string_literal: true

# Centralized error handling concern for all API controllers
# Provides consistent error responses and logging

module ErrorHandler
  extend ActiveSupport::Concern

  included do
    # Generic fallback (should be defined FIRST so it's tried LAST)
    rescue_from StandardError, with: :handle_unexpected_error

    # Database/infrastructure errors
    rescue_from ActiveRecord::ConnectionNotEstablished, with: :handle_connection_error
    rescue_from SolidQueue::Job::EnqueueError, with: :handle_queue_error

    # Service errors
    rescue_from Clients::OllamaClient::OllamaError, with: :handle_ollama_error
    rescue_from EmbeddingService::EmbeddingError, with: :handle_embedding_error
    rescue_from LlmService::LlmError, with: :handle_llm_error

    # JWT errors
    rescue_from JWT::DecodeError, with: :handle_jwt_error
    rescue_from JWT::ExpiredSignature, with: :handle_jwt_expired

    # Parameter errors
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ActionController::BadRequest, with: :handle_bad_request

    # ActiveRecord errors
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
    rescue_from ActiveRecord::RecordNotUnique, with: :handle_duplicate_error

    # Custom API errors (should be defined LAST so it's tried FIRST)
    rescue_from ApiErrors::BaseError, with: :handle_api_error
  end

  private

  def handle_queue_error(error)
    log_error(error, level: :error)
    render_error(
      {
        error: "queue_unavailable",
        message: "Background job service temporarily unavailable. Your request may have been saved but processing is delayed.",
        details: Rails.env.development? ? error.message : nil
      }.compact,
      status: :service_unavailable
    )
  end

  def handle_connection_error(error)
    log_error(error, level: :error, include_backtrace: true)
    render_error(
      {
        error: "service_unavailable",
        message: "A required service is temporarily unavailable",
        details: Rails.env.development? ? error.message : nil
      }.compact,
      status: :service_unavailable
    )
  end

  def handle_api_error(error)
    log_error(error, level: :warn)
    # Use message as error field for backwards compatibility with existing tests
    render_error(
      {
        error: error.message,
        code: error.code,
        status: Rack::Utils.status_code(error.status)
      }.tap { |h| h[:details] = error.details if error.details.present? },
      status: error.status
    )
  end

  def handle_not_found(error)
    resource = error.model || "Resource"
    render_error(
      { error: "#{resource} not found" },
      status: :not_found
    )
  end

  def handle_validation_error(error)
    log_error(error, level: :info)
    render_error(
      {
        error: "validation_failed",
        message: "Validation failed",
        errors: error.record.errors.full_messages
      },
      status: :unprocessable_entity
    )
  end

  def handle_duplicate_error(error)
    log_error(error, level: :info)
    render_error(
      { error: "conflict", message: "Resource already exists" },
      status: :conflict
    )
  end

  def handle_parameter_missing(error)
    render_error(
      {
        error: "parameter_missing",
        message: "Required parameter missing: #{error.param}"
      },
      status: :bad_request
    )
  end

  def handle_bad_request(error)
    render_error(
      { error: "bad_request", message: error.message.truncate(200) },
      status: :bad_request
    )
  end

  def handle_jwt_error(_error)
    render_error(
      { error: "invalid_token", message: "Invalid authentication token" },
      status: :unauthorized
    )
  end

  def handle_jwt_expired(_error)
    render_error(
      { error: "token_expired", message: "Authentication token has expired" },
      status: :unauthorized
    )
  end

  def handle_ollama_error(error)
    log_error(error, level: :error)
    render_error(
      {
        error: "ai_service_error",
        message: "AI service is temporarily unavailable",
        details: Rails.env.development? ? error.message : nil
      }.compact,
      status: :service_unavailable
    )
  end

  def handle_embedding_error(error)
    log_error(error, level: :error)
    render_error(
      { error: "embedding_error", message: "Failed to generate embeddings" },
      status: :unprocessable_entity
    )
  end

  def handle_llm_error(error)
    log_error(error, level: :error)
    render_error(
      { error: "llm_error", message: "Failed to generate response" },
      status: :unprocessable_entity
    )
  end

  def handle_unexpected_error(error)
    log_error(error, level: :error, include_backtrace: true)

    if Rails.env.production?
      render_error(
        {
          error: "internal_server_error",
          message: "An unexpected error occurred"
        },
        status: :internal_server_error
      )
    else
      render_error(
        {
          error: "internal_server_error",
          message: error.message,
          backtrace: error.backtrace&.first(10)
        },
        status: :internal_server_error
      )
    end
  end

  def render_error(body, status:)
    body[:request_id] = request.request_id
    body[:timestamp] = Time.current.iso8601

    render json: body, status: status
  end

  def log_error(error, level: :error, include_backtrace: false)
    message = "[#{self.class.name}] #{error.class}: #{error.message}"

    case level
    when :info
      Rails.logger.info(message)
    when :warn
      Rails.logger.warn(message)
    else
      Rails.logger.error(message)
      Rails.logger.error(error.backtrace&.first(10)&.join("\n")) if include_backtrace
    end
  end
end
