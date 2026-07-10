# Abstract base class for all models in this application.
#
# All models inherit from this class instead of +ActiveRecord::Base+
# directly. This provides a single place to add shared behaviour
# (scopes, concern includes, default settings) that should apply to
# every model in the application.
#
# Rails uses +primary_abstract_class+ to indicate that this class does
# not map to a database table — only its subclasses do.
#
# @abstract Subclass this to create a new model.
#
# @see User
# @see KnowledgeBase
# @see Document
# @see Chunk
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
