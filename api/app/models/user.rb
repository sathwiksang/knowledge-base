# Represents a registered user who can create knowledge bases and query them.
#
# This is the top-level resource in the ownership hierarchy:
#
#   User → KnowledgeBase → Document → Chunk
#
# Users authenticate via email + password (bcrypt). On login, a JWT token
# is issued by {JwtService} and must be sent with every subsequent request.
#
# == Table: +users+
#
# @!attribute [r] id
#   @return [Integer] primary key (auto-increment)
# @!attribute [rw] email
#   @return [String] unique login email, stored lowercase
#     (indexed, unique constraint)
# @!attribute [rw] password_digest
#   @return [String] bcrypt hash of the password — never exposed via API.
#     Populated automatically by +has_secure_password+ when you set
#     +password+ and +password_confirmation+.
# @!attribute [r] created_at
#   @return [DateTime] when the account was created
# @!attribute [r] updated_at
#   @return [DateTime] when the account was last modified
#
# == Validations
#
# - +email+ — required, must be a valid email format, must be unique
#   (case-insensitive). Uniqueness is enforced both in Rails and by a
#   unique database index.
# - +password+ — minimum 6 characters. Only validated on new records or
#   when the password is explicitly being changed (so updating other
#   fields doesn't require re-entering the password).
#
# @note bcrypt has a 72-byte password limit. Passwords longer than 72
#   bytes are silently truncated by bcrypt, which could lead to
#   unexpected authentication behaviour.
#
# @example Creating a user
#   user = User.create!(
#     email: "dev@example.com",
#     password: "secret123",
#     password_confirmation: "secret123"
#   )
#
# @example Authenticating (used by AuthController#login)
#   user = User.find_by(email: "dev@example.com")
#   user.authenticate("secret123") # => user or false
#
# @see JwtService Issues authentication tokens after login
# @see Api::V1::AuthController Registration and login endpoints
class User < ApplicationRecord
  # Adds +password+ and +password_confirmation+ virtual attributes,
  # bcrypt hashing, and the +authenticate+ method.
  has_secure_password

  # @!method knowledge_bases
  #   @return [ActiveRecord::Associations::CollectionProxy<KnowledgeBase>]
  #     all knowledge bases owned by this user. Destroying the user
  #     cascades to destroy all their knowledge bases (and in turn
  #     all documents and chunks).
  has_many :knowledge_bases, dependent: :destroy

  # Email must be present, unique (case-insensitive), and RFC-compliant.
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  # Password minimum 6 chars — only validated on create or explicit password change.
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }

  # Normalise email to lowercase before every save so that lookups
  # and uniqueness checks are always case-insensitive.
  before_save :downcase_email

  private

  # @return [void]
  def downcase_email
    self.email = email.downcase
  end
end
