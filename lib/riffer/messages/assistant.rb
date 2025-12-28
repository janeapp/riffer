# frozen_string_literal: true

class Riffer::Messages::Assistant < Riffer::Messages::Base
  attr_reader :tool_calls

  def initialize(content, tool_calls: [])
    super(content)
    @tool_calls = tool_calls
  end

  def role
    "assistant"
  end

  def to_h
    hash = {role: role, content: content}
    hash[:tool_calls] = tool_calls unless tool_calls.empty?
    hash
  end
end
