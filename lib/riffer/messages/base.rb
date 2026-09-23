# frozen_string_literal: true
# rbs_inline: enabled

require "securerandom"

class Riffer::Messages::Base
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::Base)) -> Riffer::Messages::Base
  def self.from_hash(msg)
    return msg if msg.is_a?(Riffer::Messages::Base)

    raise Riffer::ArgumentError, "Message hash must include a 'role' key" if msg[:role].nil? || msg[:role].empty?

    case msg[:role].to_sym
    when :user then Riffer::Messages::User.from_hash(msg)
    when :assistant then Riffer::Messages::Assistant.from_hash(msg)
    when :system then Riffer::Messages::System.from_hash(msg)
    when :tool then Riffer::Messages::Tool.from_hash(msg)
    else raise Riffer::ArgumentError, "Unknown message role: #{msg[:role]}"
    end
  end

  attr_reader :content #: String # @dynamic content

  attr_reader :id #: String? # @dynamic id

  #--
  #: (String, ?id: String?) -> void
  def initialize(content, id: nil)
    @content = content
    @id = id || generate_id
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = { role: role, content: content }
    hash[:id] = id if id
    hash
  end

  #--
  #: () -> Symbol
  def role
    raise NotImplementedError, "Subclasses must implement #role"
  end

  #--
  #: () -> bool
  def has_tool_calls?
    false
  end

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
