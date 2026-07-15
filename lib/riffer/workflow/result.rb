# frozen_string_literal: true
# rbs_inline: enabled

# The structured outcome of running a workflow. Carries the overall status,
# the final output (on success), any error (on failure), and per-step results.
class Riffer::Workflow::Result
  # @rbs @status: Symbol

  # The workflow status: +:success+ or +:failed+.
  attr_reader :status #: Symbol

  # The original input passed to the workflow.
  attr_reader :input #: Hash[Symbol, untyped]

  # The final step's validated output hash, or +nil+ on failure.
  attr_reader :output #: Hash[Symbol, untyped]?

  # The captured exception, or +nil+ on success.
  attr_reader :error #: StandardError?

  # The identifier of the step that failed, or +nil+ on success.
  attr_reader :failed_step #: String?

  # Ordered hash of step identifier to StepResult.
  attr_reader :steps #: Hash[String, Riffer::Workflow::StepResult]

  #--
  #: (status: Symbol, input: Hash[Symbol, untyped], ?output: Hash[Symbol, untyped]?, ?error: StandardError?, ?failed_step: String?, ?steps: Hash[String, Riffer::Workflow::StepResult]) -> void
  def initialize(status:, input:, output: nil, error: nil, failed_step: nil, steps: {})
    @status = status
    @input = input
    @output = output
    @error = error
    @failed_step = failed_step
    @steps = steps
  end

  #--
  #: () -> bool
  def success? = @status == :success

  #--
  #: () -> bool
  def failed? = @status == :failed

  # Returns a hash representation of the workflow result.
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    h = {status: @status, input: @input} #: Hash[Symbol, untyped]
    h[:output] = @output if @output
    h[:error] = (err = @error) ? err.message : nil if @error
    h[:failed_step] = @failed_step if @failed_step
    h[:steps] = @steps.transform_values(&:to_h)
    h
  end
end
