# frozen_string_literal: true
# rbs_inline: enabled

# Base class for all evaluators in the Riffer framework.
#
# Provides a DSL for defining evaluator metadata and the evaluate method.
# Subclasses must implement the +evaluate+ method.
#
# See Riffer::Evals::Evaluators.
#
#   class MyEvaluator < Riffer::Evals::Evaluator
#     description "Evaluates response quality"
#     higher_is_better true
#     judge_model "anthropic/claude-opus-4-5-20251101"
#
#     def evaluate(input:, output:, context: nil)
#       evaluation = judge.evaluate(
#         system_prompt: "...",
#         user_prompt: "..."
#       )
#       result(score: evaluation[:score], reason: evaluation[:reason])
#     end
#   end
#
class Riffer::Evals::Evaluator
  class << self
    # Gets or sets the evaluator description.
    #
    #: (?String?) -> String?
    def description(value = nil)
      return @description if value.nil?
      @description = value.to_s
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
  # Raises NotImplementedError if not implemented by subclass.
  #
  #: (input: String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base], output: String, ?context: Hash[Symbol, untyped]?) -> Riffer::Evals::Result
  def evaluate(input:, output:, context: nil)
    raise NotImplementedError, "#{self.class} must implement #evaluate"
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
