# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Tracing::StreamRecorder # :nodoc: all
  # @rbs @yielder: Enumerator::Yielder
  # @rbs @clock: ^() -> Float
  # @rbs @started_at: Float

  attr_reader :token_usage #: Riffer::Providers::TokenUsage? # @dynamic token_usage
  attr_reader :time_to_first_chunk #: Float? # @dynamic time_to_first_chunk
  attr_reader :finish_reason #: Symbol? # @dynamic finish_reason
  attr_reader :raw_finish_reason #: String? # @dynamic raw_finish_reason
  attr_reader :content #: String? # @dynamic content
  attr_reader :tool_calls #: Array[Riffer::Messages::Assistant::ToolCall] # @dynamic tool_calls

  #--
  #: (Enumerator::Yielder, ?clock: ^() -> Float) -> void
  def initialize(yielder, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @yielder = yielder
    @clock = clock
    @started_at = clock.call
    @tool_calls = [] #: Array[Riffer::Messages::Assistant::ToolCall]
  end

  #--
  #: (Riffer::StreamEvents::Base) -> self
  def <<(event)
    @time_to_first_chunk ||= @clock.call - @started_at
    record(event)
    @yielder << event
    self
  end

  private

  #--
  #: (Riffer::StreamEvents::Base) -> void
  def record(event)
    case event
    when Riffer::StreamEvents::TextDone
      @content = event.content
    when Riffer::StreamEvents::ToolCallDone
      @tool_calls << Riffer::Messages::Assistant::ToolCall.new(
        call_id: event.call_id,
        name: event.name,
        arguments: event.arguments,
      )
    when Riffer::StreamEvents::TokenUsageDone
      @token_usage = event.token_usage
    when Riffer::StreamEvents::FinishReasonDone
      @finish_reason = event.finish_reason
      @raw_finish_reason = event.raw_finish_reason
    end
  end
end
