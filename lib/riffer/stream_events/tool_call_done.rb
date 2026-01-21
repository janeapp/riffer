# frozen_string_literal: true

# Riffer::StreamEvents::ToolCallDone represents a completed tool call during streaming.
#
# Emitted when the LLM has finished building a tool call with complete arguments.
#
# @api public
class Riffer::StreamEvents::ToolCallDone < Riffer::StreamEvents::Base
  attr_reader :item_id, :call_id, :name, :arguments

  # Creates a new tool call done event
  # @param item_id [String] the tool call item identifier
  # @param call_id [String] the call identifier for response matching
  # @param name [String] the tool name
  # @param arguments [String] the complete arguments JSON string
  # @param role [String] the message role (defaults to "assistant")
  def initialize(item_id:, call_id:, name:, arguments:, role: "assistant")
    super(role: role)
    @item_id = item_id
    @call_id = call_id
    @name = name
    @arguments = arguments
  end

  # Converts the event to a hash
  # @return [Hash] the event data
  def to_h
    {role: @role, item_id: @item_id, call_id: @call_id, name: @name, arguments: @arguments}
  end
end
