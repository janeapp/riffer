# frozen_string_literal: true

# Riffer::StreamEvents::ToolCallDelta represents an incremental tool call chunk during streaming.
#
# Emitted when the LLM is building a tool call, containing partial argument data.
class Riffer::StreamEvents::ToolCallDelta < Riffer::StreamEvents::Base
  # The tool call item identifier.
  attr_reader :item_id

  # The tool name (may only be present in first delta).
  attr_reader :name

  # The incremental arguments JSON fragment.
  attr_reader :arguments_delta

  # Creates a new tool call delta event.
  #
  # item_id:: String - the tool call item identifier
  # name:: String or nil - the tool name (may only be present in first delta)
  # arguments_delta:: String - the incremental arguments JSON fragment
  # role:: Symbol - the message role (defaults to :assistant)
  def initialize(item_id:, arguments_delta:, name: nil, role: :assistant)
    super(role: role)
    @item_id = item_id
    @name = name
    @arguments_delta = arguments_delta
  end

  # Converts the event to a hash.
  #
  # Returns Hash - the event data.
  def to_h
    {role: @role, item_id: @item_id, name: @name, arguments_delta: @arguments_delta}.compact
  end
end
