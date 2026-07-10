# Serializes {User} records into JSON for API responses.
#
# Used by {Api::V1::AuthController} for login, registration, and profile
# endpoints. Deliberately excludes sensitive fields (+password_digest+)
# so they are never leaked to the client.
#
# == Available views
#
# | View         | Use case                              | Extra fields            |
# |-------------|---------------------------------------|-------------------------|
# | (default)   | Login, register, profile responses    | +id+, +email+, +created_at+ |
# | :with_stats | Admin dashboards, user detail pages   | + +knowledge_bases_count+   |
#
# == Default view — example
#
# Input:
#   user = User.find(1)  # email: "dev@example.com", created 2026-01-15
#
# Output:
#   UserBlueprint.render_as_hash(user)
#   # => {
#   #      "id": 1,
#   #      "email": "dev@example.com",
#   #      "created_at": "2026-01-15T10:30:00.000Z"
#   #    }
#
# == :with_stats view — example
#
# Output:
#   UserBlueprint.render_as_hash(user, view: :with_stats)
#   # => {
#   #      "id": 1,
#   #      "email": "dev@example.com",
#   #      "created_at": "2026-01-15T10:30:00.000Z",
#   #      "knowledge_bases_count": 3
#   #    }
#
# @see User The model being serialized
# @see Api::V1::AuthController Endpoints that use this blueprint
class UserBlueprint < Blueprinter::Base
  # @!attribute [r] id
  #   Primary key of the user record.
  identifier :id

  # @!attribute [r] email
  #   The user's email address (always lowercase).
  # @!attribute [r] created_at
  #   When the account was created (ISO 8601 timestamp).
  fields :email, :created_at

  # Extended view that adds usage statistics.
  # Use when displaying user profiles or admin dashboards where you
  # want to show how many knowledge bases the user has created.
  view :with_stats do
    # @!attribute [r] knowledge_bases_count
    #   Total number of knowledge bases owned by this user.
    #   Computed via +user.knowledge_bases.count+ (DB query).
    field :knowledge_bases_count do |user|
      user.knowledge_bases.count
    end
  end
end
