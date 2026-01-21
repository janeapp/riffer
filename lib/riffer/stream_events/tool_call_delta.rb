# frozen_string_literal: true

# Riffer::StreamEvents::ToolCallDelta represents an incremental tool call chunk during streaming.
#
# Emitted when the LLM is building a tool call, containing partial argument data.
#
# @api public
class Riffer::StreamEvents::ToolCallDelta < Riffer::StreamEvents::Base
  attr_reader :item_id, :name, :arguments_delta

  # Creates a new tool call delta event
  # @param item_id [String] the tool call item identifier
  # @param name [String, nil] the tool name (may only be present in first delta)
  # @param arguments_delta [String] the incremental arguments JSON fragment
  # @param role [String] the message role (defaults to "assistant")
  def initialize(item_id:, arguments_delta:, name: nil, role: "assistant")
    super(role: role)
    @item_id = item_id
    @name = name
    @arguments_delta = arguments_delta
  end

  # Converts the event to a hash
  # @return [Hash] the event data
  def to_h
    {role: @role, item_id: @item_id, name: @name, arguments_delta: @arguments_delta}.compact
  end
end
