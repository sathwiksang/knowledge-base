# frozen_string_literal: true

# Centralized API error classes for consistent error handling
# Each error includes HTTP status, error code, and user-friendly message

module ApiErrors
  # Base API error class
  class BaseError < StandardError
    attr_reader :status, :code, :details

    def initialize(message = nil, status: :internal_server_error, code: nil, details: nil)
      @status = status
      @code = code || self.class.name.demodulize.underscore
      @details = details
      super(message || default_message)
    end

    def to_h
      {
        error: code,
        message: message,
        status: Rack::Utils.status_code(status)
      }.tap do |h|
        h[:details] = details if details.present?
      end
    end

    private

    def default_message
      "An error occurred"
    end
  end

  # Authentication errors
  class AuthenticationError < BaseError
    def initialize(message = nil, **options)
      super(message, status: :unauthorized, **options)
    end

    private

    def default_message
      "Authentication required"
    end
  end

  class InvalidCredentialsError < AuthenticationError
    private

    def default_message
      "Invalid email or password"
    end
  end

  class TokenExpiredError < AuthenticationError
    private

    def default_message
      "Authentication token has expired"
    end
  end

  class TokenInvalidError < AuthenticationError
    private

    def default_message
      "Invalid authentication token"
    end
  end

  # Authorization errors
  class AuthorizationError < BaseError
    def initialize(message = nil, **options)
      super(message, status: :forbidden, **options)
    end

    private

    def default_message
      "You are not authorized to perform this action"
    end
  end

  # Resource errors
  class NotFoundError < BaseError
    def initialize(resource = "Resource", **options)
      super("#{resource} not found", status: :not_found, **options)
    end
  end

  class ResourceExistsError < BaseError
    def initialize(resource = "Resource", **options)
      super("#{resource} already exists", status: :conflict, **options)
    end
  end

  # Validation errors
  class ValidationError < BaseError
    def initialize(message = nil, errors: [], **options)
      @validation_errors = errors
      super(message, status: :unprocessable_entity, details: errors, **options)
    end

    attr_reader :validation_errors

    private

    def default_message
      "Validation failed"
    end
  end

  # Rate limiting
  class RateLimitExceededError < BaseError
    attr_reader :retry_after

    def initialize(retry_after: 60, **options)
      @retry_after = retry_after
      super("Rate limit exceeded. Retry after #{retry_after} seconds", status: :too_many_requests, **options)
    end

    def to_h
      super.merge(retry_after: retry_after)
    end
  end

  # Service errors
  class ServiceUnavailableError < BaseError
    def initialize(service = "Service", **options)
      super("#{service} is temporarily unavailable", status: :service_unavailable, **options)
    end
  end

  class ExternalServiceError < BaseError
    def initialize(service = "External service", **options)
      super("#{service} returned an error", status: :bad_gateway, **options)
    end
  end

  # Processing errors
  class ProcessingError < BaseError
    def initialize(message = nil, **options)
      super(message, status: :unprocessable_entity, **options)
    end

    private

    def default_message
      "Unable to process request"
    end
  end

  class DocumentProcessingError < ProcessingError
    private

    def default_message
      "Document processing failed"
    end
  end

  class EmbeddingGenerationError < ProcessingError
    private

    def default_message
      "Failed to generate embeddings"
    end
  end

  class SearchError < ProcessingError
    private

    def default_message
      "Search operation failed"
    end
  end

  class RagError < ProcessingError
    private

    def default_message
      "Question answering failed"
    end
  end

  # Request errors
  class BadRequestError < BaseError
    def initialize(message = nil, **options)
      super(message, status: :bad_request, **options)
    end

    private

    def default_message
      "Invalid request"
    end
  end

  class PayloadTooLargeError < BaseError
    def initialize(max_size = nil, **options)
      msg = max_size ? "Request payload too large (max: #{max_size})" : "Request payload too large"
      super(msg, status: :payload_too_large, **options)
    end
  end

  class UnsupportedMediaTypeError < BaseError
    def initialize(message = nil, **options)
      super(message, status: :unsupported_media_type, **options)
    end

    private

    def default_message
      "Unsupported content type"
    end
  end
end
