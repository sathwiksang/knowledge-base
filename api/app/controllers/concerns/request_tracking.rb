# frozen_string_literal: true

# Request tracking concern for logging and debugging
# Adds request metadata to logs and responses

module RequestTracking
  extend ActiveSupport::Concern

  included do
    before_action :track_request
    after_action :add_response_headers
  end

  private

  def track_request
    # Store request info for logging
    Thread.current[:request_start_time] = Time.current

    # Log request details
    Rails.logger.info(
      "[Request] #{request.method} #{request.path} " \
      "from #{request.remote_ip} " \
      "request_id=#{request.request_id}"
    )
  end

  def add_response_headers
    # Add useful debugging headers
    response.headers["X-Request-Id"] = request.request_id

    # Add processing time header
    if (start_time = Thread.current[:request_start_time])
      duration_ms = ((Time.current - start_time) * 1000).round(2)
      response.headers["X-Response-Time"] = "#{duration_ms}ms"
    end

    # Add API version header
    response.headers["X-API-Version"] = "v1"
  end
end
