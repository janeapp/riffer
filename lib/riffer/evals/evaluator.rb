# frozen_string_literal: true
# rbs_inline: enabled

# Base class for all evaluators. Set +instructions+ and the base class calls
# the judge automatically; override +#evaluate+ for custom logic. See
# examples/evaluators/ for reference implementations.
#
#   class MyEvaluator < Riffer::Evals::Evaluator
#     instructions "Assess medical accuracy of the response..."
#     higher_is_better true
#     judge_model "anthropic/claude-opus-4-5-20251101"
#   end
#
class Riffer::Evals::Evaluator
  # @rbs self.@instructions: String?
  # @rbs self.@higher_is_better: bool?
  # @rbs self.@judge_model: String?
  # @rbs @judge: Riffer::Evals::Judge?

  class << self
    # Gets or sets the evaluation instructions (criteria and scoring rubric).
    #
    #--
    #: (?String?) -> String?
    def instructions(value = nil)
      return @instructions if value.nil?
      @instructions = value.to_s
    end

    # Gets or sets whether higher scores are better.
    #
    #--
    #: (?bool?) -> bool
    def higher_is_better(value = nil)
      if value.nil?
        current = @higher_is_better
        return true if current.nil?
        return current
      end
      @higher_is_better = value
    end

    # Gets or sets the judge model for LLM-as-judge evaluations.
    #
    #--
    #: (?String?) -> String?
    def judge_model(value = nil)
      return @judge_model if value.nil?
      @judge_model = value.to_s
    end
  end

  # Evaluates an input/output pair. The default calls the judge with the
  # class-level +instructions+; override for custom logic (e.g. rule-based
  # evaluators).
  #--
  #: (input: String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base], output: String, ?ground_truth: String?, ?messages: Array[Riffer::Messages::Base]) -> Riffer::Evals::Result
  def evaluate(input:, output:, ground_truth: nil, messages: [])
    instr = self.class.instructions
    raise NotImplementedError, "#{self.class} must set instructions or implement #evaluate" unless instr

    evaluation = judge.evaluate(
      instructions: instr,
      input: format_input(input),
      output: output,
      ground_truth: ground_truth
    )

    result(score: evaluation[:score], reason: evaluation[:reason], token_usage: evaluation[:token_usage])
  end

  private

  #--
  #: (String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base]) -> String
  def format_input(input)
    return input if input.is_a?(String)

    input.map do |msg|
      if msg.is_a?(Hash)
        hash = msg #: Hash[untyped, untyped]
        role = hash[:role] || hash["role"]
        content = hash[:content] || hash["content"]
      else
        role = msg.role
        content = msg.content
      end
      "#{role}: #{content}"
    end.join("\n\n")
  end

  protected

  # Returns a Judge instance configured for this evaluator.
  #
  #--
  #: () -> Riffer::Evals::Judge
  def judge
    @judge ||= begin
      model = self.class.judge_model || Riffer.config.evals.judge_model
      raise Riffer::ArgumentError, "No judge model configured. Set judge_model on the evaluator or Riffer.config.evals.judge_model" unless model
      Riffer::Evals::Judge.new(model: model)
    end
  end

  # Builds a Result for this evaluator.
  #--
  #: (score: Float, ?reason: String?, ?metadata: Hash[Symbol, untyped], ?token_usage: Riffer::Providers::TokenUsage?) -> Riffer::Evals::Result
  def result(score:, reason: nil, metadata: {}, token_usage: nil)
    Riffer::Evals::Result.new(
      evaluator: self.class,
      score: score,
      reason: reason,
      metadata: metadata,
      higher_is_better: self.class.higher_is_better,
      token_usage: token_usage
    )
  end
end
