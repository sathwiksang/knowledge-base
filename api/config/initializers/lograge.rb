# frozen_string_literal: true

# Lograge configuration for structured, single-line logging
# This makes logs much easier to parse and analyze

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Keep original Rails logger for other output
  config.lograge.keep_original_rails_log = false

  # Log to STDOUT in all environments for container compatibility
  config.lograge.logger = ActiveSupport::Logger.new($stdout)

  # Custom options to include in every log line
  config.lograge.custom_options = lambda do |event|
    {
      request_id: event.payload[:request_id] || RequestStore.store[:request_id],
      user_id: event.payload[:user_id],
      ip: event.payload[:ip],
      user_agent: event.payload[:user_agent]&.truncate(100),
      time: Time.current.iso8601,
      host: event.payload[:host],
      params: filtered_params(event.payload[:params])
    }.compact
  end

  # Include exception details
  config.lograge.custom_payload do |controller|
    {
      request_id: controller.request.request_id,
      user_id: controller.try(:current_user)&.id,
      ip: controller.request.remote_ip,
      user_agent: controller.request.user_agent,
      host: controller.request.host
    }
  end

  # Ignore health check endpoints to reduce noise
  config.lograge.ignore_actions = [
    "Api::V1::HealthController#liveness",
    "Api::V1::HealthController#readiness",
    "Rails::HealthController#show"
  ]
end

def filtered_params(params)
  return nil if params.blank?

  # Filter sensitive parameters
  filtered = params.except(
    "controller", "action", "format",
    "password", "password_confirmation", "token",
    "api_key", "secret", "content" # Don't log document content
  )

  return nil if filtered.empty?

  # Truncate large values
  filtered.transform_values do |v|
    case v
    when String
      v.truncate(100)
    when Hash
      v.to_s.truncate(100)
    else
      v
    end
  end
end
