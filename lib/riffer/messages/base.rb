# frozen_string_literal: true
# rbs_inline: enabled

require "securerandom"

# Base class for all message types. Subclasses must implement +role+.
class Riffer::Messages::Base
  #--
  # @dynamic content, id

  # Builds the matching message subclass from a hash, or returns +msg+ unchanged
  # when it is already a message. Raises Riffer::ArgumentError on an invalid message.
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::Base)) -> Riffer::Messages::Base
  def self.from_hash(msg)
    return msg if msg.is_a?(Riffer::Messages::Base)

    raise Riffer::ArgumentError, "Message hash must include a 'role' key" if msg[:role].nil? || msg[:role].empty?

    case msg[:role].to_sym
    when :user
      files = (msg[:files] || []).map { |f| Riffer::Messages::FilePart.from_hash(f) }
      Riffer::Messages::User.new(msg[:content], id: msg[:id], files: files)
    when :assistant
      tool_calls = (msg[:tool_calls] || []).map do |tc|
        tc.is_a?(Riffer::Messages::Assistant::ToolCall) ? tc : Riffer::Messages::Assistant::ToolCall.new(**tc)
      end
      Riffer::Messages::Assistant.new(
        msg[:content],
        id: msg[:id],
        tool_calls: tool_calls,
        structured_output: msg[:structured_output],
        finish_reason: msg[:finish_reason]&.to_sym,
        finish_reason_raw: msg[:finish_reason_raw],
      )
    when :system
      Riffer::Messages::System.new(msg[:content], id: msg[:id])
    when :tool
      Riffer::Messages::Tool.new(msg[:content], id: msg[:id], tool_call_id: msg[:tool_call_id], name: msg[:name])
    else
      raise Riffer::ArgumentError, "Unknown message role: #{msg[:role]}"
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
