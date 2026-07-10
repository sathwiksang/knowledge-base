# frozen_string_literal: true

module Api
  module V1
    # Handles user registration, login, logout, and profile retrieval.
    #
    # == Authentication requirements
    #
    # - +register+, +login+, and +logout+ are **public** (no token needed).
    # - +profile+ requires a valid JWT in the +Authorization+ header.
    #
    # == How authentication works
    #
    # 1. A user registers or logs in and receives a JWT token in the response.
    # 2. The client stores that token (e.g. in localStorage or a cookie).
    # 3. For every subsequent request, the client sends the token as:
    #      Authorization: Bearer <token>
    # 4. The token expires after 24 hours — the client must log in again.
    #
    # == Rate limiting
    #
    # No rate limiting is currently applied at the controller level.
    # Consider adding Rack::Attack throttling for +login+ and +register+
    # in production.
    #
    # @see JwtService Encodes and decodes JWT tokens
    # @see BaseController Handles token verification on protected endpoints
    class AuthController < BaseController
      skip_authentication :register, :login, :logout

      # ----------------------------------------------------------------
      # GET /api/v1/auth/profile
      # ----------------------------------------------------------------
      # Returns the authenticated user's profile information.
      #
      # == Authentication
      # Required — send a valid JWT in the Authorization header.
      #
      # == Parameters
      # None.
      #
      # == Success response (200 OK)
      #   {
      #     "user": {
      #       "id": 1,
      #       "email": "user@example.com",
      #       "created_at": "2026-01-01T00:00:00Z"
      #     },
      #     "request_id": "abc-123"
      #   }
      #
      # == Error responses
      # - 401 Unauthorized — missing or invalid token
      #
      # == Example curl
      #   curl -H "Authorization: Bearer <token>" \
      #        http://localhost:3000/api/v1/auth/profile
      def profile
        render_success(user: UserBlueprint.render_as_hash(current_user))
      end

      # ----------------------------------------------------------------
      # POST /api/v1/auth/register
      # ----------------------------------------------------------------
      # Creates a new user account and returns a JWT token.
      #
      # == Authentication
      # Not required (public endpoint).
      #
      # == Required parameters (JSON body)
      # - +email+        [String] — must be a valid, unique email address
      # - +password+     [String] — minimum length defined by model validations
      #   (bcrypt has a 72-byte limit)
      # - +password_confirmation+ [String] — must match +password+
      #
      # == Success response (201 Created)
      #   {
      #     "message": "User created successfully",
      #     "user": {
      #       "id": 1,
      #       "email": "user@example.com",
      #       "created_at": "2026-01-01T00:00:00Z"
      #     },
      #     "token": "eyJhbGciOiJIUzI1NiJ9...",
      #     "request_id": "abc-123"
      #   }
      #
      # == Error responses
      # - 422 Unprocessable Entity — validation failed (duplicate email,
      #   password mismatch, etc.)
      #     {
      #       "error": "validation_failed",
      #       "message": "Validation failed",
      #       "errors": ["Email has already been taken"],
      #       "request_id": "abc-123",
      #       "timestamp": "2026-01-01T00:00:00Z"
      #     }
      #
      # == Example curl
      #   curl -X POST http://localhost:3000/api/v1/auth/register \
      #        -H "Content-Type: application/json" \
      #        -d '{"email":"user@example.com","password":"secret123","password_confirmation":"secret123"}'
      def register
        user = User.new(user_params)

        if user.save
          token = JwtService.encode(user_id: user.id)
          render_created(
            message: "User created successfully",
            user: UserBlueprint.render_as_hash(user),
            token: token
          )
        else
          render_unprocessable(user.errors.full_messages)
        end
      end

      # ----------------------------------------------------------------
      # POST /api/v1/auth/login
      # ----------------------------------------------------------------
      # Authenticates an existing user and returns a JWT token.
      #
      # == Authentication
      # Not required (public endpoint).
      #
      # == Required parameters (JSON body)
      # - +email+    [String] — the user's registered email (case-insensitive)
      # - +password+ [String] — the user's password
      #
      # == Success response (200 OK)
      #   {
      #     "message": "Login successful",
      #     "user": {
      #       "id": 1,
      #       "email": "user@example.com",
      #       "created_at": "2026-01-01T00:00:00Z"
      #     },
      #     "token": "eyJhbGciOiJIUzI1NiJ9...",
      #     "request_id": "abc-123"
      #   }
      #
      # == Error responses
      # - 401 Unauthorized — wrong email or password
      #     {
      #       "error": "Invalid email or password",
      #       "code": "invalid_credentials",
      #       "status": 401,
      #       "request_id": "abc-123",
      #       "timestamp": "2026-01-01T00:00:00Z"
      #     }
      #
      # == Example curl
      #   curl -X POST http://localhost:3000/api/v1/auth/login \
      #        -H "Content-Type: application/json" \
      #        -d '{"email":"user@example.com","password":"secret123"}'
      def login
        user = User.find_by(email: params[:email]&.downcase&.strip)

        if user&.authenticate(params[:password])
          token = JwtService.encode(user_id: user.id)
          render_success(
            message: "Login successful",
            user: UserBlueprint.render_as_hash(user),
            token: token
          )
        else
          raise ApiErrors::InvalidCredentialsError
        end
      end

      # ----------------------------------------------------------------
      # DELETE /api/v1/auth/logout
      # ----------------------------------------------------------------
      # Logs the user out. With stateless JWT, this is a no-op on the
      # server side — the client should discard its stored token.
      #
      # This endpoint exists for API completeness and as a hook for
      # future server-side token blacklisting.
      #
      # == Authentication
      # Not required (but the client typically sends the token anyway).
      #
      # == Parameters
      # None.
      #
      # == Success response (200 OK)
      #   {
      #     "message": "Logged out successfully",
      #     "request_id": "abc-123"
      #   }
      #
      # == Example curl
      #   curl -X DELETE http://localhost:3000/api/v1/auth/logout \
      #        -H "Authorization: Bearer <token>"
      def logout
        # For stateless JWT, logout is handled client-side by discarding the token.
        # This endpoint exists for API completeness and future token blacklisting.
        render_success(message: "Logged out successfully")
      end

      private

      # Strong parameters for user registration.
      #
      # @return [ActionController::Parameters] permitted params:
      #   +email+, +password+, +password_confirmation+
      def user_params
        params.permit(:email, :password, :password_confirmation)
      end
    end
  end
end
