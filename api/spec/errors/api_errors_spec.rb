# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiErrors do
  describe ApiErrors::BaseError do
    it 'has default status :internal_server_error' do
      error = described_class.new
      expect(error.status).to eq(:internal_server_error)
    end

    it 'uses default message when none provided' do
      error = described_class.new
      expect(error.message).to eq("An error occurred")
    end

    it 'accepts a custom message' do
      error = described_class.new("Custom error")
      expect(error.message).to eq("Custom error")
    end

    it 'derives code from class name when not provided' do
      error = described_class.new
      expect(error.code).to eq("base_error")
    end

    it 'accepts a custom code' do
      error = described_class.new(code: "custom_code")
      expect(error.code).to eq("custom_code")
    end

    it 'accepts details' do
      error = described_class.new(details: { field: "invalid" })
      expect(error.details).to eq({ field: "invalid" })
    end

    describe '#to_h' do
      it 'returns a hash with error, message, and status' do
        error = described_class.new("Test error", code: "test")
        hash = error.to_h
        expect(hash[:error]).to eq("test")
        expect(hash[:message]).to eq("Test error")
        expect(hash[:status]).to eq(500)
      end

      it 'includes details when present' do
        error = described_class.new(details: "extra info")
        expect(error.to_h[:details]).to eq("extra info")
      end

      it 'excludes details when nil' do
        error = described_class.new
        expect(error.to_h).not_to have_key(:details)
      end
    end
  end

  describe ApiErrors::AuthenticationError do
    it 'has status :unauthorized' do
      expect(described_class.new.status).to eq(:unauthorized)
    end

    it 'has default message' do
      expect(described_class.new.message).to eq("Authentication required")
    end
  end

  describe ApiErrors::InvalidCredentialsError do
    it 'inherits unauthorized status' do
      expect(described_class.new.status).to eq(:unauthorized)
    end

    it 'has default message' do
      expect(described_class.new.message).to eq("Invalid email or password")
    end
  end

  describe ApiErrors::TokenExpiredError do
    it 'has default message' do
      expect(described_class.new.message).to eq("Authentication token has expired")
    end
  end

  describe ApiErrors::TokenInvalidError do
    it 'has default message' do
      expect(described_class.new.message).to eq("Invalid authentication token")
    end
  end

  describe ApiErrors::AuthorizationError do
    it 'has status :forbidden' do
      expect(described_class.new.status).to eq(:forbidden)
    end

    it 'has default message' do
      expect(described_class.new.message).to eq("You are not authorized to perform this action")
    end
  end

  describe ApiErrors::NotFoundError do
    it 'has status :not_found' do
      expect(described_class.new.status).to eq(:not_found)
    end

    it 'includes resource name in message' do
      expect(described_class.new("Document").message).to eq("Document not found")
    end

    it 'defaults to Resource' do
      expect(described_class.new.message).to eq("Resource not found")
    end
  end

  describe ApiErrors::ResourceExistsError do
    it 'has status :conflict' do
      expect(described_class.new.status).to eq(:conflict)
    end

    it 'includes resource name in message' do
      expect(described_class.new("KnowledgeBase").message).to eq("KnowledgeBase already exists")
    end
  end

  describe ApiErrors::ValidationError do
    it 'has status :unprocessable_entity' do
      expect(described_class.new.status).to eq(:unprocessable_entity)
    end

    it 'stores validation errors' do
      error = described_class.new(errors: ["Name is required", "Email is invalid"])
      expect(error.validation_errors).to eq(["Name is required", "Email is invalid"])
    end

    it 'passes errors as details' do
      error = described_class.new(errors: ["Name is required"])
      expect(error.details).to eq(["Name is required"])
    end

    it 'has default message' do
      expect(described_class.new.message).to eq("Validation failed")
    end
  end

  describe ApiErrors::RateLimitExceededError do
    it 'has status :too_many_requests' do
      expect(described_class.new.status).to eq(:too_many_requests)
    end

    it 'includes retry_after in message' do
      error = described_class.new(retry_after: 30)
      expect(error.message).to include("30 seconds")
    end

    it 'defaults retry_after to 60' do
      expect(described_class.new.retry_after).to eq(60)
    end

    it 'includes retry_after in to_h' do
      error = described_class.new(retry_after: 45)
      expect(error.to_h[:retry_after]).to eq(45)
    end
  end

  describe ApiErrors::ServiceUnavailableError do
    it 'has status :service_unavailable' do
      expect(described_class.new.status).to eq(:service_unavailable)
    end

    it 'includes service name' do
      expect(described_class.new("Ollama").message).to eq("Ollama is temporarily unavailable")
    end
  end

  describe ApiErrors::ExternalServiceError do
    it 'has status :bad_gateway' do
      expect(described_class.new.status).to eq(:bad_gateway)
    end

    it 'includes service name' do
      expect(described_class.new("Ollama API").message).to eq("Ollama API returned an error")
    end
  end

  describe ApiErrors::ProcessingError do
    it 'has status :unprocessable_entity' do
      expect(described_class.new.status).to eq(:unprocessable_entity)
    end

    it 'has default message' do
      expect(described_class.new.message).to eq("Unable to process request")
    end
  end

  describe ApiErrors::DocumentProcessingError do
    it 'has default message' do
      expect(described_class.new.message).to eq("Document processing failed")
    end
  end

  describe ApiErrors::EmbeddingGenerationError do
    it 'has default message' do
      expect(described_class.new.message).to eq("Failed to generate embeddings")
    end
  end

  describe ApiErrors::SearchError do
    it 'has default message' do
      expect(described_class.new.message).to eq("Search operation failed")
    end
  end

  describe ApiErrors::RagError do
    it 'has default message' do
      expect(described_class.new.message).to eq("Question answering failed")
    end
  end

  describe ApiErrors::BadRequestError do
    it 'has status :bad_request' do
      expect(described_class.new.status).to eq(:bad_request)
    end

    it 'has default message' do
      expect(described_class.new.message).to eq("Invalid request")
    end
  end

  describe ApiErrors::PayloadTooLargeError do
    it 'has status :payload_too_large' do
      expect(described_class.new.status).to eq(:payload_too_large)
    end

    it 'includes max_size when provided' do
      expect(described_class.new("10MB").message).to eq("Request payload too large (max: 10MB)")
    end

    it 'has generic message when no max_size' do
      expect(described_class.new.message).to eq("Request payload too large")
    end
  end

  describe ApiErrors::UnsupportedMediaTypeError do
    it 'has status :unsupported_media_type' do
      expect(described_class.new.status).to eq(:unsupported_media_type)
    end

    it 'has default message' do
      expect(described_class.new.message).to eq("Unsupported content type")
    end
  end
end
