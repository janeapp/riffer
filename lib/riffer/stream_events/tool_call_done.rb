# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StreamEvents::ToolCallDone < Riffer::StreamEvents::Base
  attr_reader :item_id #: String
  attr_reader :call_id #: String
  attr_reader :name #: String
  attr_reader :arguments #: String

  #: (item_id: String, call_id: String, name: String, arguments: String, ?role: Symbol) -> void
  def initialize(item_id:, call_id:, name:, arguments:, role: :assistant)
    super(role: role)
    @item_id = item_id
    @call_id = call_id
    @name = name
    @arguments = arguments
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: @role, item_id: @item_id, call_id: @call_id, name: @name, arguments: @arguments}
  end
end
