# frozen_string_literal: true
# rbs_inline: enabled

# Base class for all message types in the Riffer framework.
#
# Subclasses must implement the +role+ method.
class Riffer::Messages::Base
  # The message content.
  attr_reader :content #: String

  #: content: String
  #: return: void
  def initialize(content)
    @content = content
  end

  # Converts the message to a hash.
  #
  #: return: Hash[Symbol, untyped]
  def to_h
    {role: role, content: content}
  end

  # Returns the message role.
  #
  # Raises NotImplementedError if not implemented by subclass.
  #
  #: return: Symbol
  def role
    raise NotImplementedError, "Subclasses must implement #role"
  end
end
