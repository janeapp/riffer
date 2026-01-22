# frozen_string_literal: true

# Module for converting hashes to message objects.
#
# Included in Agent and Provider classes to handle message normalization.
module Riffer::Messages::Converter
  # Converts a hash or message object to a Riffer::Messages::Base subclass.
  #
  # msg:: Hash or Riffer::Messages::Base - the message to convert
  #
  # Returns Riffer::Messages::Base subclass.
  #
  # Raises Riffer::ArgumentError if the message format is invalid.
  def convert_to_message_object(msg)
    return msg if msg.is_a?(Riffer::Messages::Base)

    unless msg.is_a?(Hash)
      raise Riffer::ArgumentError, "Message must be a Hash or Message object, got #{msg.class}"
    end

    convert_hash_to_message(msg)
  end

  private

  def convert_hash_to_message(hash)
    role = hash[:role] || hash["role"]
    content = hash[:content] || hash["content"]

    if role.nil? || role.empty?
      raise Riffer::ArgumentError, "Message hash must include a 'role' key"
    end

    case role
    when "user"
      Riffer::Messages::User.new(content)
    when "assistant"
      tool_calls = hash[:tool_calls] || hash["tool_calls"] || []
      Riffer::Messages::Assistant.new(content, tool_calls: tool_calls)
    when "system"
      Riffer::Messages::System.new(content)
    when "tool"
      tool_call_id = hash[:tool_call_id] || hash["tool_call_id"]
      name = hash[:name] || hash["name"]
      Riffer::Messages::Tool.new(content, tool_call_id: tool_call_id, name: name)
    else
      raise Riffer::ArgumentError, "Unknown message role: #{role}"
    end
  end
end
