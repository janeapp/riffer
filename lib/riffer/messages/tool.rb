# frozen_string_literal: true

module Riffer::Messages
  class Tool < Base
    attr_reader :tool_call_id, :name

    def initialize(content, tool_call_id:, name:)
      raise ArgumentError, "Tool message tool_call_id is required, got: #{tool_call_id.inspect}" if tool_call_id.nil? || (tool_call_id.respond_to?(:empty?) && tool_call_id.empty?)
      raise ArgumentError, "Tool message name is required, got: #{name.inspect}" if name.nil? || (name.respond_to?(:empty?) && name.empty?)

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
