# frozen_string_literal: true
# rbs_inline: enabled

# Module for converting hashes to message objects.
#
# Included in Agent and Provider classes to handle message normalization.
module Riffer::Messages::Converter
  # Converts a hash or message object to a Riffer::Messages::Base subclass.
  #
  # Raises Riffer::ArgumentError if the message format is invalid.
  #
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::Base)) -> Riffer::Messages::Base
  def convert_to_message_object(msg)
    return msg if msg.is_a?(Riffer::Messages::Base)

    unless msg.is_a?(Hash)
      raise Riffer::ArgumentError, "Message must be a Hash or Message object, got #{msg.class}"
    end

    convert_hash_to_message(msg)
  end

  # Converts a hash or FilePart object to a Riffer::Messages::FilePart.
  #
  # Accepts:
  # - +Riffer::Messages::FilePart+ objects (passed through)
  # - <tt>{url: "https://...", media_type: "..."}</tt> (URL source)
  # - <tt>{data: "...", media_type: "..."}</tt> (raw base64)
  #
  # Raises Riffer::ArgumentError if the hash format is invalid.
  #
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::FilePart)) -> Riffer::Messages::FilePart
  def convert_to_file_part(file)
    return file if file.is_a?(Riffer::Messages::FilePart)

    unless file.is_a?(Hash)
      raise Riffer::ArgumentError, "File must be a Hash or FilePart object, got #{file.class}"
    end

    url = file[:url]
    data = file[:data]
    media_type = file[:media_type]
    filename = file[:filename]

    if url
      Riffer::Messages::FilePart.from_url(url, media_type: media_type)
    elsif data && media_type
      Riffer::Messages::FilePart.new(data: data, media_type: media_type, filename: filename)
    else
      raise Riffer::ArgumentError, "File hash must include :url or :data with :media_type"
    end
  end

  private

  #--
  #: (Hash[Symbol, untyped]) -> Riffer::Messages::Base
  def convert_hash_to_message(hash)
    role = hash[:role]
    content = hash[:content]

    if role.nil? || role.empty?
      raise Riffer::ArgumentError, "Message hash must include a 'role' key"
    end

    id = hash[:id]

    case role.to_sym
    when :user
      files = (hash[:files] || []).map { |f| convert_to_file_part(f) }
      Riffer::Messages::User.new(content, id: id, files: files)
    when :assistant
      tool_calls = (hash[:tool_calls] || []).map { |tc|
        tc.is_a?(Riffer::Messages::Assistant::ToolCall) ? tc : Riffer::Messages::Assistant::ToolCall.new(**tc)
      }
      structured_output = hash[:structured_output]
      Riffer::Messages::Assistant.new(content, id: id, tool_calls: tool_calls, structured_output: structured_output)
    when :system
      Riffer::Messages::System.new(content, id: id)
    when :tool
      tool_call_id = hash[:tool_call_id]
      name = hash[:name]
      Riffer::Messages::Tool.new(content, id: id, tool_call_id: tool_call_id, name: name)
    else
      raise Riffer::ArgumentError, "Unknown message role: #{role}"
    end
  end
end
