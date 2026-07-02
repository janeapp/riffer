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
  #: (tool: String, call_id: String, outcome: Symbol, duration: Float, ?error: Exception?, ?error_type: String?, ?tags: Hash[String, String], ?trace_id: String?, ?span_id: String?) -> void
  def initialize(tool:, call_id:, outcome:, duration:, error: nil, error_type: nil, tags: {}, trace_id: nil, span_id: nil)
    super(duration: duration, error: error, error_type: error_type, tags: tags, trace_id: trace_id, span_id: span_id)
    @tool = tool
    @call_id = call_id
    @outcome = outcome
  end

  # The dotted event name.
  #--
  #: () -> String
  def name = "riffer.execute_tool"

  # Tool and outcome, on top of the shared dimensions. The call id is unbounded,
  # so it stays a typed accessor rather than a metric label.
  #--
  #: () -> Hash[String, String]
  def dimensions
    super.merge("tool" => tool, "outcome" => outcome.to_s)
  end
end
