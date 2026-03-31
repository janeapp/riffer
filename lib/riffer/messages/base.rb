# frozen_string_literal: true
# rbs_inline: enabled

# Base class for all message types in the Riffer framework.
#
# Subclasses must implement the +role+ method.
class Riffer::Messages::Base
  # The message content.
  attr_reader :content #: String

  # The time the message was created.
  attr_reader :timestamp #: Time

  #--
  #: (String, ?timestamp: Time) -> void
  def initialize(content, timestamp: Time.now)
    @content = content
    @timestamp = timestamp
  end

  # Converts the message to a hash.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: role, content: content, timestamp: timestamp.iso8601(3)}
  end

  # Returns the message role.
  #
  # Raises NotImplementedError if not implemented by subclass.
  #
  #--
  #: () -> Symbol
  def role
    raise NotImplementedError, "Subclasses must implement #role"
  end
end
