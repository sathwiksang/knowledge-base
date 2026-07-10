# frozen_string_literal: true

module Api
  module V1
    # Base controller for all API v1 endpoints.
    #
    # Every controller under +Api::V1+ inherits from this class and
    # automatically gets:
    #
    # - **JWT authentication** — a valid +Authorization: Bearer <token>+
    #   header is required on every request unless explicitly skipped
    #   with {.skip_authentication}.
    # - **Owner-based authorization** — the {#authorize_resource!} helper
    #   ensures users can only access their own resources.
    # - **Pagination helpers** — {#pagination_params} normalises +page+
    #   and +per_page+ query params (max 100 per page).
    # - **Consistent error handling** — inherited from {ApplicationController}
    #   via the {ErrorHandler} concern.
    # - **Standardised JSON responses** — inherited via the {ApiResponse}
    #   concern (+render_success+, +render_created+, etc.).
    #
    # == Authentication flow
    #
    #   1. Client sends: Authorization: Bearer <jwt_token>
    #   2. BaseController extracts the token from the header
    #   3. JwtService.decode verifies the signature and expiry
    #   4. The user is loaded from the database and set as current_user
    #   5. If any step fails → 401 Unauthorized JSON response
    #
    # == Skipping authentication
    #
    # Public endpoints (login, register, health) opt out by calling
    # +skip_authentication+ at the class level:
    #
    #   class AuthController < BaseController
    #     skip_authentication :register, :login
    #   end
    #
    # @see JwtService Token encoding/decoding
    # @see ErrorHandler Centralised error handling
    # @see ApiResponse Standardised response helpers
    class BaseController < ApplicationController
      before_action :authenticate_request

      # @return [User] the currently authenticated user (set after
      #   successful JWT verification)
      attr_reader :current_user

      # Class-level helper to skip JWT authentication for specific actions.
      #
      # @param actions [Array<Symbol>] action names that should be publicly
      #   accessible without a token
      #
      # @example
      #   skip_authentication :register, :login, :logout
      def self.skip_authentication(*actions)
        skip_before_action :authenticate_request, only: actions
      end

      private

      # Authenticate the incoming request by extracting and verifying
      # the JWT from the Authorization header.
      #
      # Sets +@current_user+ on success. Raises an {ApiErrors::AuthenticationError}
      # (which the {ErrorHandler} maps to a 401 response) on failure.
      #
      # @raise [ApiErrors::AuthenticationError] if the token is missing,
      #   invalid, expired, or the user no longer exists
      def authenticate_request
        token = extract_token_from_header

        if token.blank?
          raise ApiErrors::AuthenticationError, "Missing authentication token"
        end

        payload = JwtService.decode(token)
        @current_user = User.find(payload[:user_id])
      rescue JwtService::AuthenticationError => e
        raise ApiErrors::AuthenticationError, e.message
      rescue ActiveRecord::RecordNotFound
        raise ApiErrors::AuthenticationError, "User not found"
      end

      # Extract the JWT token from the Authorization header.
      #
      # Accepts two formats:
      # - +Bearer <token>+ (standard OAuth 2.0 format)
      # - +<token>+ (bare token for convenience)
      #
      # @return [String, nil] the raw JWT string, or nil if no header present
      def extract_token_from_header
        header = request.headers["Authorization"]
        return nil unless header.present?

        parts = header.split(" ")
        parts.length == 2 ? parts.last : parts.first
      end

      # Verify that the authenticated user owns the given resource.
      #
      # @param resource [ApplicationRecord] any record with a +user_id+ column
      # @raise [ApiErrors::AuthorizationError] if the resource belongs to
      #   a different user (results in a 403 Forbidden response)
      def authorize_resource!(resource)
        return if resource.user_id == current_user.id

        raise ApiErrors::AuthorizationError
      end

      # Normalise and clamp pagination parameters from the query string.
      #
      # @return [Hash] with keys +:page+ (Integer, default 1) and
      #   +:per_page+ (Integer, default 20, max 100)
      def pagination_params
        {
          page: params[:page]&.to_i || 1,
          per_page: [ params[:per_page]&.to_i || 20, 100 ].min
        }
      end
    end
  end
end
