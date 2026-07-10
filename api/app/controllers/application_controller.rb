# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ErrorHandler
  include ApiResponse
  include RequestTracking

  # Set default response format
  before_action :ensure_json_content_type

  private

  def ensure_json_content_type
    return unless request.post? || request.put? || request.patch?
    return if request.content_type.blank? || request.body.read.blank?

    request.body.rewind

    unless request.content_type.to_s.include?("application/json")
      render_bad_request("Content-Type must be application/json")
    end
  end
end
