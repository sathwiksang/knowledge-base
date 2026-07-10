require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module KnowledgeBaseApi
  class Application < Rails::Application
    config.load_defaults 8.0
    config.autoload_lib(ignore: %w[assets tasks])

    # Autoload lib directory (for Clients::OllamaClient etc.)
    config.autoload_paths << Rails.root.join("lib")

    # API-only mode
    config.api_only = true

    # Time zone
    config.time_zone = "UTC"

    # Active Job adapter
    config.active_job.queue_adapter = :solid_queue

    # Middleware stack configuration
    # Request ID middleware for distributed tracing
    require_relative "../lib/middleware/request_id_middleware"
    config.middleware.insert_before ActionDispatch::RequestId, Middleware::RequestIdMiddleware

    # JSON error handling for parsing errors
    require_relative "../lib/middleware/json_error_middleware"
    config.middleware.insert_before Rack::Head, Middleware::JsonErrorMiddleware

    # Rack::Attack for rate limiting (configured in initializer)
    config.middleware.use Rack::Attack

    # Request Store for per-request storage
    config.middleware.use RequestStore::Middleware

    # Generator settings
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end

    # Exception handling in development
    config.action_dispatch.show_exceptions = :rescuable unless Rails.env.development?

    # Security headers
    config.action_dispatch.default_headers = {
      "X-Frame-Options" => "DENY",
      "X-Content-Type-Options" => "nosniff",
      "X-XSS-Protection" => "1; mode=block",
      "X-Download-Options" => "noopen",
      "X-Permitted-Cross-Domain-Policies" => "none",
      "Referrer-Policy" => "strict-origin-when-cross-origin",
      "Strict-Transport-Security" => "max-age=31536000; includeSubDomains; preload",
      "Permissions-Policy" => "camera=(), microphone=(), geolocation=(), payment=()"
    }
  end
end
