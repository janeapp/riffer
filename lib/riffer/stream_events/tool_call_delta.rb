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

  #: (item_id: String, arguments_delta: String, ?name: String?, ?role: Symbol) -> void
  def initialize(item_id:, arguments_delta:, name: nil, role: :assistant)
    super(role: role)
    @item_id = item_id
    @name = name
    @arguments_delta = arguments_delta
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: @role, item_id: @item_id, name: @name, arguments_delta: @arguments_delta}.compact
  end
end
