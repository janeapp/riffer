# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Evals::Evaluator
  class << self
    #: (?String?) -> String?
    def instructions(value = nil)
      return @instructions if value.nil?
      @instructions = value.to_s
    end

    #: (?bool?) -> bool
    def higher_is_better(value = nil)
      return @higher_is_better.nil? || @higher_is_better if value.nil?
      @higher_is_better = value
    end

    #: (?String?) -> String?
    def judge_model(value = nil)
      return @judge_model if value.nil?
      @judge_model = value.to_s
    end
  end

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

    result(score: evaluation[:score], reason: evaluation[:reason])
  end

  private

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

  #: () -> Riffer::Evals::Judge
  def judge
    @judge ||= begin
      model = self.class.judge_model || Riffer.config.evals.judge_model
      raise Riffer::ArgumentError, "No judge model configured. Set judge_model on the evaluator or Riffer.config.evals.judge_model" unless model
      Riffer::Evals::Judge.new(model: model)
    end
  end

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
