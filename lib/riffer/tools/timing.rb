# frozen_string_literal: true
# rbs_inline: enabled

# Records how long a single tool call took to execute.
#
# When +Riffer.config.report_timings+ is enabled, the tool runtime measures each
# tool call — the dispatch plus any +around_tool_call+ wrapper — and produces
# one Timing per call.
#
# Unlike guardrails, a tool that errors or times out is still timed: the runtime
# captures the failure into a Riffer::Tools::Response rather than raising, so
# +error_type+ records the outcome and +duration+ covers the failed attempt.
#
#   timing = Timing.new(
#     tool_name: "get_weather",
#     call_id: "call_123",
#     duration: 0.42,
#     error_type: nil
#   )
#   timing.kind     # => :tool
#   timing.success? # => true
class Riffer::Tools::Timing < Riffer::Timing
  # The name of the tool that was called.
  attr_reader :tool_name #: String

  # The tool call id, used to correlate parallel calls to the same tool.
  attr_reader :call_id #: String

  # The error type when the call failed (:unknown_tool, :validation_error,
  # :execution_error, :timeout_error), or +nil+ on success.
  attr_reader :error_type #: Symbol?

  # Creates a new timing record.
  #
  # [tool_name] the name of the tool that ran.
  # [call_id] the tool call id.
  # [duration] execution time in seconds.
  # [error_type] the error type, or +nil+ on success.
  #
  #--
  #: (tool_name: String, call_id: String, duration: Float, ?error_type: Symbol?) -> void
  def initialize(tool_name:, call_id:, duration:, error_type: nil)
    super(duration: duration)
    @tool_name = tool_name
    @call_id = call_id
    @error_type = error_type
  end

  # Identifies this as a tool timing.
  #
  #--
  #: () -> Symbol
  def kind = :tool

  # Returns true if the tool call succeeded.
  #
  #--
  #: () -> bool
  def success? = error_type.nil?

  # Converts the timing to a hash.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    super.merge(tool_name: tool_name, call_id: call_id, error_type: error_type)
  end
end
