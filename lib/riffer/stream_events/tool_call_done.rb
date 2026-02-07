# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::StreamEvents::ToolCallDone represents a completed tool call during streaming.
#
# Emitted when the LLM has finished building a tool call with complete arguments.
class Riffer::StreamEvents::ToolCallDone < Riffer::StreamEvents::Base
  # The tool call item identifier.
  attr_reader :item_id #: String

  # The call identifier for response matching.
  attr_reader :call_id #: String

  # The tool name.
  attr_reader :name #: String

  # The complete arguments JSON string.
  attr_reader :arguments #: String

  #: item_id: String -- the tool call item identifier
  #: call_id: String -- the call identifier for response matching
  #: name: String -- the tool name
  #: arguments: String -- the complete arguments JSON string
  #: role: Symbol -- the message role (defaults to :assistant)
  #: return: void
  def initialize(item_id:, call_id:, name:, arguments:, role: :assistant)
    super(role: role)
    @item_id = item_id
    @call_id = call_id
    @name = name
    @arguments = arguments
  end

  #: return: Hash[Symbol, untyped]
  def to_h
    {role: @role, item_id: @item_id, call_id: @call_id, name: @name, arguments: @arguments}
  end
end
