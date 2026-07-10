# Handles JSON Web Token (JWT) encoding and decoding for API authentication.
#
# This service provides stateless authentication by issuing and verifying
# HS256-signed JWTs. Tokens include an expiration claim ({EXPIRATION_TIME})
# and an issued-at claim for security. All methods are class-level for
# convenient use without instantiation.
#
# @note Tokens without an +exp+ claim are rejected on decode (the +jwt+ gem
#   enforces this when verification is enabled).
# @note bcrypt has a 72-byte password limit — keep this in mind when
#   hashing passwords used alongside JWT auth.
#
# @example Encoding a token for a user
#   token = JwtService.encode(user_id: user.id)
#   # => "eyJhbGciOiJIUzI1NiJ9..."
#
# @example Decoding a token from a request header
#   payload = JwtService.decode(token)
#   user = User.find(payload[:user_id])
#
# @see ApplicationController#authenticate_request
class JwtService
  # @!attribute [r] SECRET_KEY
  #   @return [String] signing secret sourced from ENV or Rails credentials
  SECRET_KEY = ENV.fetch("JWT_SECRET_KEY") { Rails.application.credentials.secret_key_base }

  # @!attribute [r] ALGORITHM
  #   @return [String] HMAC signing algorithm used for all tokens
  ALGORITHM = "HS256".freeze

  # @!attribute [r] EXPIRATION_TIME
  #   @return [ActiveSupport::Duration] token lifetime (24 hours)
  EXPIRATION_TIME = 24.hours

  class << self
    # Encode a payload into a signed JWT string.
    #
    # Automatically injects +exp+ (expiration) and +iat+ (issued-at) claims
    # into the payload before signing.
    #
    # @param payload [Hash] arbitrary data to include in the token
    #   (e.g. +{ user_id: 1 }+)
    # @return [String] the signed JWT string
    #
    # @example
    #   JwtService.encode(user_id: 42)
    #   # => "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0Mn0..."
    def encode(payload)
      payload[:exp] = EXPIRATION_TIME.from_now.to_i
      payload[:iat] = Time.current.to_i
      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    # Decode and verify a JWT string, returning the original payload.
    #
    # Verifies the signature and checks that the token has not expired.
    # Returns an +HashWithIndifferentAccess+ so callers can use either
    # symbol or string keys.
    #
    # @param token [String] the JWT string to decode
    # @return [HashWithIndifferentAccess] the decoded payload
    # @raise [AuthenticationError] if the token is expired or invalid
    #
    # @example
    #   payload = JwtService.decode("eyJhbGci...")
    #   payload[:user_id] # => 42
    def decode(token)
      decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: ALGORITHM, required_claims: ["exp"] })
      HashWithIndifferentAccess.new(decoded.first)
    rescue JWT::ExpiredSignature
      raise AuthenticationError, "Token has expired"
    rescue JWT::DecodeError => e
      raise AuthenticationError, "Invalid token: #{e.message}"
    end
  end

  # Raised when token encoding/decoding fails due to expiration or
  # signature verification issues.
  class AuthenticationError < StandardError; end
end
