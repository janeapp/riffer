# frozen_string_literal: true
# rbs_inline: enabled

require "securerandom"

# Base class for all message types. Subclasses must implement +role+.
class Riffer::Messages::Base
  # The message content.
  attr_reader :content #: String

  # The message id, or nil when +Riffer.config.message_id_strategy+ is +:none+.
  attr_reader :id #: String?

  #--
  #: (String, ?id: String?) -> void
  def initialize(content, id: nil)
    @content = content
    @id = id || generate_id
  end

  # Converts the message to a hash.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = {role: role, content: content}
    hash[:id] = id unless id.nil?
    hash
  end

  # Returns the message role.
  #--
  #: () -> Symbol
  def role
    raise NotImplementedError, "Subclasses must implement #role"
  end

  # Whether this message carries pending tool calls (overridden by
  # +Riffer::Messages::Assistant+).
  #--
  #: () -> bool
  def has_tool_calls?
    false
  end

  # Merges another same-role message into this one. +Tool+ messages are never
  # merged.
  #--
  #: (untyped) -> Riffer::Messages::Base
  def +(other)
    raise NotImplementedError, "Subclasses must implement #+"
  end

  private

  #: () -> String?
  def generate_id
    case Riffer.config.message_id_strategy
    when :uuid then SecureRandom.uuid
    when :uuidv7 then SecureRandom.uuid_v7
    end
  end
end
