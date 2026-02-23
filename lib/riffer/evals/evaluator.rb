# frozen_string_literal: true
# rbs_inline: enabled

# Base class for all evaluators in the Riffer framework.
#
# Provides a DSL for defining evaluator metadata and the evaluate method.
# Simple evaluators only need to set +instructions+ — the base class
# handles calling the judge automatically.
#
# See examples/evaluators/ for reference implementations.
#
#   class MyEvaluator < Riffer::Evals::Evaluator
#     instructions "Assess medical accuracy of the response..."
#     higher_is_better true
#     judge_model "anthropic/claude-opus-4-5-20251101"
#   end
#
class Riffer::Evals::Evaluator
  class << self
    # Gets or sets the evaluation instructions (criteria and scoring rubric).
    #
    #: (?String?) -> String?
    def instructions(value = nil)
      return @instructions if value.nil?
      @instructions = value.to_s
    end

    # Gets or sets whether higher scores are better.
    #
    #: (?bool?) -> bool
    def higher_is_better(value = nil)
      return @higher_is_better.nil? || @higher_is_better if value.nil?
      @higher_is_better = value
    end

    # Gets or sets the judge model for LLM-as-judge evaluations.
    #
    #: (?String?) -> String?
    def judge_model(value = nil)
      return @judge_model if value.nil?
      @judge_model = value.to_s
    end
  end

  # Evaluates an input/output pair.
  #
  # The default implementation calls the judge with the class-level +instructions+.
  # Override this method for custom evaluation logic (e.g. rule-based evaluators).
  #
  # +input+ - the input to evaluate; String or Array of message hashes/Message objects.
  # +output+ - the agent's response to evaluate.
  # +ground_truth+ - optional reference answer for comparison.
  #
  # Raises NotImplementedError if neither +instructions+ is set nor +evaluate+ is overridden.
  #
  #: (input: String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base], output: String, ?ground_truth: String?) -> Riffer::Evals::Result
  def evaluate(input:, output:, ground_truth: nil)
    instr = self.class.instructions
    raise NotImplementedError, "#{self.class} must set instructions or implement #evaluate" unless instr

    evaluation = judge.evaluate(
      instructions: instr,
      input: format_input(input),
      output: output,
      ground_truth: ground_truth
    )

    result(score: evaluation[:score], reason: evaluation[:reason])
  end

  private

  # Formats the input for the judge.
  #
  # String inputs are passed through as-is.
  # Array inputs (message hashes or Message objects) are formatted
  # as labeled role/content pairs separated by blank lines.
  #
  #: (String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base]) -> String
  def format_input(input)
    return input if input.is_a?(String)

    input.map do |msg|
      role = msg.is_a?(Hash) ? (msg[:role] || msg["role"]) : msg.role
      content = msg.is_a?(Hash) ? (msg[:content] || msg["content"]) : msg.content
      "#{role}: #{content}"
    end.join("\n\n")
  end

  protected

  # Returns a Judge instance configured for this evaluator.
  #
  #: () -> Riffer::Evals::Judge
  def judge
    @judge ||= begin
      model = self.class.judge_model || Riffer.config.evals.judge_model
      raise Riffer::ArgumentError, "No judge model configured. Set judge_model on the evaluator or Riffer.config.evals.judge_model" unless model
      Riffer::Evals::Judge.new(model: model)
    end
  end

  # Helper to build a Result object.
  #
  #: (score: Float, ?reason: String?, ?metadata: Hash[Symbol, untyped]) -> Riffer::Evals::Result
  def result(score:, reason: nil, metadata: {})
    Riffer::Evals::Result.new(
      evaluator: self.class,
      score: score,
      reason: reason,
      metadata: metadata,
      higher_is_better: self.class.higher_is_better
    )
  end
end
