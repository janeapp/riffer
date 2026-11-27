# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Providers::DeferredToolGateway::Sink
  # @rbs @sink: Riffer::Providers::_EventSink
  # @rbs @deferred_tools: Array[singleton(Riffer::Tool)]
  # @rbs @gateway_item_ids: Array[String]

  #--
  #: (Riffer::Providers::_EventSink, deferred_tools: Array[singleton(Riffer::Tool)]) -> void
  def initialize(sink, deferred_tools:)
    @sink = sink
    @deferred_tools = deferred_tools
    @gateway_item_ids = []
  end

  #--
  #: (Riffer::StreamEvents::Base) -> self
  def <<(event)
    case event
    when Riffer::StreamEvents::ToolCallDelta
      # A gateway call's deltas are fragments of its own arguments, which only unwrap once the call is complete.
      # Providers may name the call on its first delta alone, so the rest are matched by item id.
      @gateway_item_ids |= [event.item_id] if event.name == Riffer::Providers::DeferredToolGateway::Tool.name
      @sink << event unless @gateway_item_ids.include?(event.item_id)
    when Riffer::StreamEvents::ToolCallDone
      @sink << unwrap(event)
    else
      @sink << event
    end
    self
  end

  private

  #--
  #: (Riffer::StreamEvents::ToolCallDone) -> Riffer::StreamEvents::ToolCallDone
  def unwrap(event)
    tool_call = Riffer::Messages::Assistant::ToolCall.new(
      call_id: event.call_id,
      name: event.name,
      arguments: event.arguments,
    )
    unwrapped = Riffer::Providers::DeferredToolGateway.unwrap_tool_call(tool_call, @deferred_tools)
    return event if unwrapped.equal?(tool_call)

    Riffer::StreamEvents::ToolCallDone.new(
      item_id: event.item_id,
      call_id: unwrapped.call_id,
      name: unwrapped.name,
      arguments: unwrapped.arguments,
    )
  end
end
