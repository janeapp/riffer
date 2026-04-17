# frozen_string_literal: true
# rbs_inline: enabled

require "securerandom"

# Base class for all message types in the Riffer framework.
#
# Subclasses must implement the +role+ method.
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
  #
  # Raises NotImplementedError if not implemented by subclass.
  #
  #--
  #: () -> Symbol
  def role
    raise NotImplementedError, "Subclasses must implement #role"
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
