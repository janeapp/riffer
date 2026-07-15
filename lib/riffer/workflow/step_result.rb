# frozen_string_literal: true
# rbs_inline: enabled

# Captures the outcome of a single step within a workflow run.
class Riffer::Workflow::StepResult
  # @rbs @status: Symbol
  # @rbs @output: Hash[Symbol, untyped]?
  # @rbs @error: StandardError?
  # @rbs @payload: Hash[Symbol, untyped]?

  # The step status: +:success+, +:failed+, or +:pending+.
  attr_reader :status #: Symbol

  # The validated output hash, or +nil+ unless the step succeeded.
  attr_reader :output #: Hash[Symbol, untyped]?

  # The captured exception, or +nil+ unless the step failed.
  attr_reader :error #: StandardError?

  # The input received by this step, or +nil+ when pending.
  attr_reader :payload #: Hash[Symbol, untyped]?

  #--
  #: (status: Symbol, ?output: Hash[Symbol, untyped]?, ?error: StandardError?, ?payload: Hash[Symbol, untyped]?) -> void
  def initialize(status:, output: nil, error: nil, payload: nil)
    @status = status
    @output = output
    @error = error
    @payload = payload
  end

  #--
  #: () -> bool
  def success? = @status == :success

  #--
  #: () -> bool
  def failed? = @status == :failed

  #--
  #: () -> bool
  def pending? = @status == :pending

  # Returns a hash representation of this step result.
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    h = {status: @status} #: Hash[Symbol, untyped]
    h[:payload] = @payload if @payload
    h[:output] = @output if @output
    h[:error] = (err = @error) ? err.message : nil if @error
    h
  end
end
