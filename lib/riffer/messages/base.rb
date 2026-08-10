# frozen_string_literal: true
# rbs_inline: enabled

require "securerandom"

# Base class for all message types. Subclasses must implement +role+.
class Riffer::Messages::Base
  # Builds the matching message subclass from a hash, or returns +msg+ unchanged
  # when it is already a message. Raises Riffer::ArgumentError on an invalid message.
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::Base)) -> Riffer::Messages::Base
  def self.from_hash(msg)
    return msg if msg.is_a?(Riffer::Messages::Base)

    raise Riffer::ArgumentError, "Message must be a Hash or Message object, got #{msg.class}" unless msg.is_a?(Hash)

    role = msg[:role]
    content = msg[:content]

    raise Riffer::ArgumentError, "Message hash must include a 'role' key" if role.nil? || role.empty?

    id = msg[:id]

    case role.to_sym
    when :user
      files = (msg[:files] || []).map { |f| Riffer::Messages::FilePart.from_hash(f) }
      Riffer::Messages::User.new(content, id: id, files: files)
    when :assistant
      tool_calls = (msg[:tool_calls] || []).map do |tc|
        tc.is_a?(Riffer::Messages::Assistant::ToolCall) ? tc : Riffer::Messages::Assistant::ToolCall.new(**tc)
      end
      structured_output = msg[:structured_output]
      finish_reason = msg[:finish_reason]&.to_sym
      Riffer::Messages::Assistant.new(content, id: id, tool_calls: tool_calls, structured_output: structured_output,
                                               finish_reason: finish_reason,)
    when :system
      Riffer::Messages::System.new(content, id: id)
    when :tool
      tool_call_id = msg[:tool_call_id]
      name = msg[:name]
      Riffer::Messages::Tool.new(content, id: id, tool_call_id: tool_call_id, name: name)
    else
      raise Riffer::ArgumentError, "Unknown message role: #{role}"
    end
  end

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
    hash = { role: role, content: content }
    hash[:id] = id if id
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
