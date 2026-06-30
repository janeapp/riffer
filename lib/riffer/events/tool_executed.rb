# frozen_string_literal: true
# rbs_inline: enabled

# Published when a tool call finishes. A returned error response and a raised
# exception both yield +outcome+ +:error+; the latter also carries +error+.
class Riffer::Events::ToolExecuted < Riffer::Events::Base
  # The tool name.
  attr_reader :tool #: String

  # The provider-assigned tool call id.
  attr_reader :call_id #: String

  # The outcome, +:success+ or +:error+.
  attr_reader :outcome #: Symbol

  #--
  #: (tool: String, call_id: String, outcome: Symbol, duration: Float, ?error_type: String?, ?error: Exception?, ?tags: Hash[String, String], ?trace_id: String?, ?span_id: String?) -> void
  def initialize(tool:, call_id:, outcome:, duration:, error_type: nil, error: nil, tags: {}, trace_id: nil, span_id: nil)
    super(duration: duration, error_type: error_type, error: error, tags: tags, trace_id: trace_id, span_id: span_id)
    @tool = tool
    @call_id = call_id
    @outcome = outcome
  end

  # The operation identifier.
  #--
  #: () -> Symbol
  def operation = :execute_tool

  # The dotted event name.
  #--
  #: () -> String
  def name = "riffer.execute_tool"
end
