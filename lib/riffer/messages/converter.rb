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
  #: ((Hash[Symbol | String, untyped] | Riffer::Messages::Base)) -> Riffer::Messages::Base
  def convert_to_message_object(msg)
    return msg if msg.is_a?(Riffer::Messages::Base)

    unless msg.is_a?(Hash)
      raise Riffer::ArgumentError, "Message must be a Hash or Message object, got #{msg.class}"
    end

    convert_hash_to_message(msg)
  end

  # Converts a hash or FilePart object to a Riffer::FilePart.
  #
  # Accepts:
  # - +Riffer::FilePart+ objects (passed through)
  # - +{url: "https://...", media_type: "..."}+ (URL source)
  # - +{data: "...", media_type: "..."}+ (raw base64)
  #
  # Raises Riffer::ArgumentError if the hash format is invalid.
  #
  #: ((Hash[Symbol | String, untyped] | Riffer::FilePart)) -> Riffer::FilePart
  def convert_to_file_part(file)
    return file if file.is_a?(Riffer::FilePart)

    unless file.is_a?(Hash)
      raise Riffer::ArgumentError, "File must be a Hash or FilePart object, got #{file.class}"
    end

    url = file[:url] || file["url"]
    data = file[:data] || file["data"]
    media_type = file[:media_type] || file["media_type"]
    filename = file[:filename] || file["filename"]

    if url
      Riffer::FilePart.from_url(url, media_type: media_type)
    elsif data && media_type
      Riffer::FilePart.new(data: data, media_type: media_type, filename: filename)
    else
      raise Riffer::ArgumentError, "File hash must include :url or :data with :media_type"
    end
  end

  private

  #: (Hash[Symbol | String, untyped]) -> Riffer::Messages::Base
  def convert_hash_to_message(hash)
    role = hash[:role] || hash["role"]
    content = hash[:content] || hash["content"]

    if role.nil? || role.empty?
      raise Riffer::ArgumentError, "Message hash must include a 'role' key"
    end

    case role.to_sym
    when :user
      files = (hash[:files] || hash["files"] || []).map { |f| convert_to_file_part(f) }
      Riffer::Messages::User.new(content, files: files)
    when :assistant
      tool_calls = hash[:tool_calls] || hash["tool_calls"] || []
      structured_output = hash[:structured_output] || hash["structured_output"]
      Riffer::Messages::Assistant.new(content, tool_calls: tool_calls, structured_output: structured_output)
    when :system
      Riffer::Messages::System.new(content)
    when :tool
      tool_call_id = hash[:tool_call_id] || hash["tool_call_id"]
      name = hash[:name] || hash["name"]
      Riffer::Messages::Tool.new(content, tool_call_id: tool_call_id, name: name)
    else
      raise Riffer::ArgumentError, "Unknown message role: #{role}"
    end
  end
end
