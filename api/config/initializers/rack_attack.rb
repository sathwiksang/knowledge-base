# frozen_string_literal: true

# Rack::Attack configuration for API rate limiting and protection
# This provides industry-grade protection against abuse and DDoS attacks

class Rack::Attack
  ### Configure Cache ###
  # Use Rails cache for storing rate limit data
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Disable in test environment ###
  # Rack::Attack should be disabled in tests to avoid flaky tests
  Rack::Attack.enabled = !Rails.env.test?

  ### Throttle Rules ###

  # General API rate limit: 100 requests per minute per IP
  throttle("api/ip", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Stricter limit for authentication endpoints: 5 requests per 20 seconds
  throttle("auth/ip", limit: 5, period: 20.seconds) do |req|
    if req.path.start_with?("/api/v1/auth/")
      req.ip
    end
  end

  # Stricter limit for login attempts: 5 per minute per IP
  throttle("auth/login/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/login" && req.post?
  end

  # Registration rate limit: 3 per hour per IP
  throttle("auth/register/ip", limit: 3, period: 1.hour) do |req|
    req.ip if req.path == "/api/v1/auth/register" && req.post?
  end

  # Search endpoint: 30 requests per minute (computationally expensive)
  throttle("search/ip", limit: 30, period: 1.minute) do |req|
    req.ip if req.path.match?(%r{/api/v1/knowledge_bases/\d+/search}) && req.post?
  end

  # Ask (RAG) endpoint: 20 requests per minute (very expensive - LLM calls)
  throttle("ask/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.path.match?(%r{/api/v1/knowledge_bases/\d+/ask}) && req.post?
  end

  # Document upload: 10 per minute
  throttle("documents/create/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.match?(%r{/api/v1/knowledge_bases/\d+/documents}) && req.post?
  end

  # Per-user rate limit (authenticated requests): 200 per minute
  throttle("api/user", limit: 200, period: 1.minute) do |req|
    if req.path.start_with?("/api/") && req.env["HTTP_AUTHORIZATION"].present?
      # Extract user from JWT token for user-specific rate limiting
      begin
        token = req.env["HTTP_AUTHORIZATION"]&.split(" ")&.last
        if token
          secret = ENV.fetch("JWT_SECRET_KEY") { Rails.application.credentials.secret_key_base }
          decoded = JWT.decode(token, secret, true, algorithm: "HS256")
          decoded.first["user_id"]
        end
      rescue JWT::DecodeError
        nil
      end
    end
  end

  ### Blocklist Rules ###

  # Block requests with XSS, scanner, or path traversal signatures
  blocklist("block-bad-requests") do |req|
    Rack::Attack::Fail2Ban.filter("suspicious-#{req.ip}", maxretry: 3, findtime: 10.minutes, bantime: 1.hour) do
      CGI.unescape(req.query_string).match?(
        /(<script|javascript:|onclick|onerror|onload|onfocus|onmouse|eval\s*\(|document\.|window\.|alert\s*\()/i
      ) ||
        req.path.match?(/\.(php|asp|aspx|jsp|cgi|pl|sh|bat|cmd|exe|dll|com)$/i) ||
        req.path.include?("..") ||
        req.path.match?(/\/wp-|\/admin\/|\/\.env|\/\.git|\/xmlrpc|\/cgi-bin/i) ||
        req.path.match?(/\/phpmyadmin|\/myadmin|\/pma|\/dbadmin/i)
    end
  end

  # Block SQL injection attempts (stricter: 2 strikes = 2 hour ban)
  blocklist("block-sql-injection") do |req|
    Rack::Attack::Fail2Ban.filter("sqli-#{req.ip}", maxretry: 2, findtime: 10.minutes, bantime: 2.hours) do
      decoded_qs = CGI.unescape(req.query_string)
      decoded_qs.match?(
        /(\bUNION\b.*\bSELECT\b|\bDROP\b\s+\bTABLE\b|\bINSERT\b\s+\bINTO\b.*\bVALUES\b|
         \bDELETE\b\s+\bFROM\b|\bUPDATE\b\s+\w+\s+\bSET\b|
         \/\*.*\*\/|--\s|;\s*DROP|;\s*DELETE|;\s*UPDATE|;\s*INSERT|
         \bEXEC\b\s*\(|\bxp_\w+|\bsp_\w+|
         \bSLEEP\s*\(|\bBENCHMARK\s*\(|\bWAITFOR\b|
         \bLOAD_FILE\s*\(|\bINTO\s+OUTFILE\b|\bINTO\s+DUMPFILE\b|
         \bINFORMATION_SCHEMA\b|\bpg_catalog\b|\bpg_tables\b)/ix
      )
    end
  end

  # Block access to sensitive paths (1 strike = 1 hour ban)
  blocklist("block-sensitive-paths") do |req|
    Rack::Attack::Fail2Ban.filter("sensitive-path-#{req.ip}", maxretry: 1, findtime: 10.minutes, bantime: 1.hour) do
      req.path.match?(
        /\/(\.env|\.git|\.svn|\.hg|\.DS_Store|
         config\/|credentials|secrets|
         debug|console|phpinfo|
         server-status|server-info|
         actuator|
         backup|dump|\.sql|\.bak|
         Gemfile|package\.json|
         node_modules|vendor\/|
         \.aws|\.ssh|\.bash_history)/ix
      )
    end
  end

  # Block repeated failed login attempts (lockout)
  blocklist("fail2ban/login") do |req|
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 10, findtime: 1.minute, bantime: 10.minutes) do
      req.path == "/api/v1/auth/login" && req.post?
    end
  end

  ### Custom Response ###

  # Return JSON responses for blocked requests
  self.blocklisted_responder = lambda do |env|
    request_id = env["action_dispatch.request_id"] || SecureRandom.uuid
    [
      429,
      {
        "Content-Type" => "application/json",
        "X-Request-Id" => request_id
      },
      [ {
        error: "Too many requests",
        message: "Your IP has been temporarily blocked due to suspicious activity",
        retry_after: 600,
        request_id: request_id
      }.to_json ]
    ]
  end

  self.throttled_responder = lambda do |env|
    match_data = env["rack.attack.match_data"]
    now = match_data[:epoch_time]
    retry_after = match_data[:period] - (now % match_data[:period])
    request_id = env["action_dispatch.request_id"] || SecureRandom.uuid

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s,
        "X-RateLimit-Limit" => match_data[:limit].to_s,
        "X-RateLimit-Remaining" => "0",
        "X-RateLimit-Reset" => (now + retry_after).to_s,
        "X-Request-Id" => request_id
      },
      [ {
        error: "Rate limit exceeded",
        message: "You have exceeded the rate limit for this endpoint",
        retry_after: retry_after.to_i,
        limit: match_data[:limit],
        period: match_data[:period],
        request_id: request_id
      }.to_json ]
    ]
  end

  ### Logging ###

  # Log throttled requests
  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _request_id, payload|
    request = payload[:request]
    Rails.logger.warn(
      "[RackAttack] Throttled: #{request.ip} #{request.request_method} #{request.path} " \
      "- #{payload[:match_type]}: #{payload[:match_data]}"
    )
  end

  # Log blocked requests
  ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |_name, _start, _finish, _request_id, payload|
    request = payload[:request]
    Rails.logger.warn(
      "[RackAttack] Blocked: #{request.ip} #{request.request_method} #{request.path}"
    )
  end
end
