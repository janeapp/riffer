# frozen_string_literal: true

# Riffer::StreamEvents::ToolCallDone represents a completed tool call during streaming.
#
# Emitted when the LLM has finished building a tool call with complete arguments.
class Riffer::StreamEvents::ToolCallDone < Riffer::StreamEvents::Base
  # The tool call item identifier.
  attr_reader :item_id

  # The call identifier for response matching.
  attr_reader :call_id

  # The tool name.
  attr_reader :name

  # The complete arguments JSON string.
  attr_reader :arguments

  # Creates a new tool call done event.
  #
  # item_id:: String - the tool call item identifier
  # call_id:: String - the call identifier for response matching
  # name:: String - the tool name
  # arguments:: String - the complete arguments JSON string
  # role:: Symbol - the message role (defaults to :assistant)
  def initialize(item_id:, call_id:, name:, arguments:, role: :assistant)
    super(role: role)
    @item_id = item_id
    @call_id = call_id
    @name = name
    @arguments = arguments
  end

  # Converts the event to a hash.
  #
  # Returns Hash - the event data.
  def to_h
    {role: @role, item_id: @item_id, call_id: @call_id, name: @name, arguments: @arguments}
  end
end
