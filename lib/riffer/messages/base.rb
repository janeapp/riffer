# frozen_string_literal: true

# Base class for all message types in the Riffer framework.
#
# Subclasses must implement the +role+ method.
class Riffer::Messages::Base
  # The message content.
  #
  # Returns String.
  attr_reader :content

  # Creates a new message.
  #
  # content:: String - the message content
  def initialize(content)
    @content = content
  end

  # Converts the message to a hash.
  #
  # Returns Hash with +:role+ and +:content+ keys.
  def to_h
    {role: role, content: content}
  end

  # Returns the message role.
  #
  # Raises NotImplementedError if not implemented by subclass.
  def role
    raise NotImplementedError, "Subclasses must implement #role"
  end
end
