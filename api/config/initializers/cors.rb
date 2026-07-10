# frozen_string_literal: true

# CORS configuration
# Origins can be configured via CORS_ORIGINS env var (comma-separated)
# or falls back to secure defaults.
cors_origins = if ENV["CORS_ORIGINS"].present?
                 ENV["CORS_ORIGINS"].split(",").map(&:strip)
               else
                 [
                   "https://sathwiksangeethamproject.dev",
                   "https://kb.sathwiksangeethamproject.dev",
                   "http://localhost:3001",
                   "http://127.0.0.1:3001"
                 ]
               end

# In production, filter out localhost origins for safety
if Rails.env.production?
  cors_origins = cors_origins.reject { |origin| origin.match?(/localhost|127\.0\.0\.1/) }
  cors_origins = [ "https://sathwiksangeethamproject.dev", "https://kb.sathwiksangeethamproject.dev" ] if cors_origins.empty?
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*cors_origins)

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose: [ "Authorization" ],
      max_age: 3600
  end
end
