# frozen_string_literal: true
# rbs_inline: enabled

# Wraps a stream yielder to observe terminal events for span stamping while
# forwarding every event downstream untouched.
class Riffer::Tracing::StreamRecorder # :nodoc: all
  # @rbs @yielder: Enumerator::Yielder
  # @rbs @clock: ^() -> Float
  # @rbs @started_at: Float

  attr_reader :token_usage #: Riffer::Providers::TokenUsage?

  attr_reader :time_to_first_chunk #: Float?

  attr_reader :finish_reason #: Symbol?

  attr_reader :raw_finish_reason #: String?

  attr_reader :content #: String?

  attr_reader :tool_calls #: Array[Riffer::Messages::Assistant::ToolCall]

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
      @tool_calls << Riffer::Messages::Assistant::ToolCall.new(call_id: event.call_id, name: event.name,
                                                               arguments: event.arguments,)
    when Riffer::StreamEvents::TokenUsageDone
      @token_usage = event.token_usage
    when Riffer::StreamEvents::FinishReasonDone
      @finish_reason = event.finish_reason
      @raw_finish_reason = event.raw_finish_reason
    end
  end
end
