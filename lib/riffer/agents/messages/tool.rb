# frozen_string_literal: true

module Riffer::Agents::Messages
  class Tool < Base
    attr_reader :tool_call_id, :name

    def initialize(content, tool_call_id:, name:)
      super(content)
      @tool_call_id = tool_call_id
      @name = name
    end

    def role
      "tool"
    end

    def to_h
      {role: role, content: content, tool_call_id: tool_call_id, name: name}
    end
  end
end
