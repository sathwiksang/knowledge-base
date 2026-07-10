# Rate limiting (Rack::Attack) — SOC 2-aligned abuse protection.
# Uses Rails.cache as the counter store.
class Rack::Attack
  # Global request ceiling per client IP (excludes static assets).
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets", "/_next", "/up", "/health")
  end

  # Tight limit on authentication attempts per IP.
  throttle("auth/ip", limit: 10, period: 1.minute) do |req|
    if req.post? && req.path.match?(%r{login|session|sign_in|auth/})
      req.ip
    end
  end

  self.throttled_responder = lambda do |_req|
    [429, { "Content-Type" => "application/json" },
     [{ error: "rate_limited", message: "Too many requests. Slow down." }.to_json]]
  end
end
