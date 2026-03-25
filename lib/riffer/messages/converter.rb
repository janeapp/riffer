# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Messages::Converter
  #: ((Hash[Symbol, untyped] | Riffer::Messages::Base)) -> Riffer::Messages::Base
  def convert_to_message_object(msg)
    return msg if msg.is_a?(Riffer::Messages::Base)

    unless msg.is_a?(Hash)
      raise Riffer::ArgumentError, "Message must be a Hash or Message object, got #{msg.class}"
    end

    convert_hash_to_message(msg)
  end

  #: ((Hash[Symbol, untyped] | Riffer::FilePart)) -> Riffer::FilePart
  def convert_to_file_part(file)
    return file if file.is_a?(Riffer::FilePart)

    unless file.is_a?(Hash)
      raise Riffer::ArgumentError, "File must be a Hash or FilePart object, got #{file.class}"
    end

    url = file[:url]
    data = file[:data]
    media_type = file[:media_type]
    filename = file[:filename]

    if url
      Riffer::FilePart.from_url(url, media_type: media_type)
    elsif data && media_type
      Riffer::FilePart.new(data: data, media_type: media_type, filename: filename)
    else
      raise Riffer::ArgumentError, "File hash must include :url or :data with :media_type"
    end
  end

  private

  #: (Hash[Symbol, untyped]) -> Riffer::Messages::Base
  def convert_hash_to_message(hash)
    role = hash[:role]
    content = hash[:content]

    if role.nil? || role.empty?
      raise Riffer::ArgumentError, "Message hash must include a 'role' key"
    end

    case role.to_sym
    when :user
      files = (hash[:files] || []).map { |f| convert_to_file_part(f) }
      Riffer::Messages::User.new(content, files: files)
    when :assistant
      tool_calls = (hash[:tool_calls] || []).map { |tc|
        tc.is_a?(Riffer::Messages::Assistant::ToolCall) ? tc : Riffer::Messages::Assistant::ToolCall.new(**tc)
      }
      structured_output = hash[:structured_output]
      Riffer::Messages::Assistant.new(content, tool_calls: tool_calls, structured_output: structured_output)
    when :system
      Riffer::Messages::System.new(content)
    when :tool
      tool_call_id = hash[:tool_call_id]
      name = hash[:name]
      Riffer::Messages::Tool.new(content, tool_call_id: tool_call_id, name: name)
    else
      raise Riffer::ArgumentError, "Unknown message role: #{role}"
    end
  end
end
