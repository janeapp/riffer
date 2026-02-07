# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::StreamEvents::ToolCallDelta represents an incremental tool call chunk during streaming.
#
# Emitted when the LLM is building a tool call, containing partial argument data.
class Riffer::StreamEvents::ToolCallDelta < Riffer::StreamEvents::Base
  # The tool call item identifier.
  attr_reader :item_id #: String

  # The tool name (may only be present in first delta).
  attr_reader :name #: String?

  # The incremental arguments JSON fragment.
  attr_reader :arguments_delta #: String

  #: item_id: String -- the tool call item identifier
  #: arguments_delta: String -- the incremental arguments JSON fragment
  #: name: String? -- the tool name (may only be present in first delta)
  #: role: Symbol -- the message role (defaults to :assistant)
  #: return: void
  def initialize(item_id:, arguments_delta:, name: nil, role: :assistant)
    super(role: role)
    @item_id = item_id
    @name = name
    @arguments_delta = arguments_delta
  end

  #: return: Hash[Symbol, untyped]
  def to_h
    {role: @role, item_id: @item_id, name: @name, arguments_delta: @arguments_delta}.compact
  end
end
