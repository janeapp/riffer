# frozen_string_literal: true

class Riffer::Messages::Tool < Riffer::Messages::Base
  attr_reader :tool_call_id, :name, :error, :error_type

  def initialize(content, tool_call_id:, name:, error: nil, error_type: nil)
    super(content)
    @tool_call_id = tool_call_id
    @name = name
    @error = error
    @error_type = error_type
  end

  def error?
    !@error.nil?
  end

  def role
    "tool"
  end

  def to_h
    hash = {role: role, content: content, tool_call_id: tool_call_id, name: name}
    if error?
      hash[:error] = error
      hash[:error_type] = error_type
    end
    hash
  end
end
