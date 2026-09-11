# frozen_string_literal: true
# rbs_inline: enabled

# Represents a completed tool call during streaming.
class Riffer::StreamEvents::ToolCallDone < Riffer::StreamEvents::Base
  # The tool call item identifier.
  attr_reader :item_id #: String

  # The call identifier for response matching.
  attr_reader :call_id #: String

  # The tool name.
  attr_reader :name #: String

  # The complete arguments JSON string.
  attr_reader :arguments #: String

  # The provider's opaque replay token for this tool call, for the providers
  # that sign one (Gemini).
  attr_reader :signature #: String?

  #--
  #: (item_id: String, call_id: String, name: String, arguments: String, ?signature: String?, ?role: Symbol) -> void
  def initialize(item_id:, call_id:, name:, arguments:, signature: nil, role: :assistant)
    super(role: role)
    @item_id = item_id
    @call_id = call_id
    @name = name
    @arguments = arguments
    @signature = signature
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = {
      role: @role, item_id: @item_id, call_id: @call_id, name: @name, arguments: @arguments,
    } #: Hash[Symbol, untyped]
    hash[:signature] = @signature if @signature
    hash
  end
end
