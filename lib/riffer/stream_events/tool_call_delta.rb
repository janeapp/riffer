# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StreamEvents::ToolCallDelta < Riffer::StreamEvents::Base
  attr_reader :item_id #: String # @dynamic item_id

  # Providers may send the name only on the first delta.
  attr_reader :name #: String? # @dynamic name

  attr_reader :arguments_delta #: String # @dynamic arguments_delta

  #--
  #: (item_id: String, arguments_delta: String, ?name: String?, ?role: Symbol) -> void
  def initialize(item_id:, arguments_delta:, name: nil, role: :assistant)
    super(role: role)
    @item_id = item_id
    @name = name
    @arguments_delta = arguments_delta
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    { role: @role, item_id: @item_id, name: @name, arguments_delta: @arguments_delta }.compact
  end
end
