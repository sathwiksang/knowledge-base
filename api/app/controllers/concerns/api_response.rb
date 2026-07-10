# frozen_string_literal: true

# Standardized API response formatting
# Ensures consistent response structure across all endpoints

module ApiResponse
  extend ActiveSupport::Concern

  included do
    before_action :set_default_response_format
  end

  private

  def set_default_response_format
    request.format = :json unless params[:format]
  end

  # Success responses
  def render_success(data = nil, status: :ok, meta: nil, **kwargs)
    response_body = if data.is_a?(Hash)
                      data
    elsif kwargs.any?
                      kwargs
    elsif data.nil?
                      {}
    else
                      { data: data }
    end
    response_body[:meta] = meta if meta.present?
    response_body[:request_id] = request.request_id

    render json: response_body, status: status
  end

  def render_created(data = nil, location: nil, **kwargs)
    response_body = if data.is_a?(Hash)
                      data
    elsif kwargs.any?
                      kwargs
    else
                      { data: data }
    end
    response_body[:request_id] = request.request_id

    if location
      render json: response_body, status: :created, location: location
    else
      render json: response_body, status: :created
    end
  end

  def render_no_content
    head :no_content
  end

  def render_accepted(data = {})
    response_body = data.is_a?(Hash) ? data : { data: data }
    response_body[:request_id] = request.request_id

    render json: response_body, status: :accepted
  end

  # Error responses
  def render_unprocessable(errors, error_code: "validation_failed")
    errors_array = errors.is_a?(Array) ? errors : [ errors ]

    render json: {
      error: error_code,
      message: "Validation failed",
      errors: errors_array,
      request_id: request.request_id,
      timestamp: Time.current.iso8601
    }, status: :unprocessable_entity
  end

  def render_not_found(resource = "Resource")
    render json: {
      error: "#{resource} not found",
      request_id: request.request_id,
      timestamp: Time.current.iso8601
    }, status: :not_found
  end

  def render_unauthorized(message = "Authentication required")
    render json: {
      error: "unauthorized",
      message: message,
      request_id: request.request_id,
      timestamp: Time.current.iso8601
    }, status: :unauthorized
  end

  def render_forbidden(message = "Access denied")
    render json: {
      error: "forbidden",
      message: message,
      request_id: request.request_id,
      timestamp: Time.current.iso8601
    }, status: :forbidden
  end

  def render_bad_request(message)
    render json: {
      error: "bad_request",
      message: message,
      request_id: request.request_id,
      timestamp: Time.current.iso8601
    }, status: :bad_request
  end

  def render_service_unavailable(service = "Service")
    render json: {
      error: "service_unavailable",
      message: "#{service} is temporarily unavailable",
      request_id: request.request_id,
      timestamp: Time.current.iso8601
    }, status: :service_unavailable
  end

  # Pagination helpers
  def pagination_meta(collection)
    return {} unless collection.respond_to?(:total_pages)

    {
      pagination: {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count,
        per_page: collection.limit_value
      }
    }
  end

  # Rate limit headers (for informational purposes)
  def set_rate_limit_headers(limit:, remaining:, reset_at:)
    response.headers["X-RateLimit-Limit"] = limit.to_s
    response.headers["X-RateLimit-Remaining"] = remaining.to_s
    response.headers["X-RateLimit-Reset"] = reset_at.to_i.to_s
  end
end
