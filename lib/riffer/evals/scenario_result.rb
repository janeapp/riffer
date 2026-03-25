# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Evals::ScenarioResult
  attr_reader :input #: String

  attr_reader :output #: String

  attr_reader :ground_truth #: String?

  attr_reader :results #: Array[Riffer::Evals::Result]

  attr_reader :messages #: Array[Riffer::Messages::Base]

  #: (input: String, output: String, ground_truth: String?, results: Array[Riffer::Evals::Result], ?messages: Array[Riffer::Messages::Base]) -> void
  def initialize(input:, output:, ground_truth:, results:, messages: [])
    @input = input
    @output = output
    @ground_truth = ground_truth
    @results = results
    @messages = messages
  end

  #: () -> Hash[singleton(Riffer::Evals::Evaluator), Float]
  def scores
    results.each_with_object({}) do |result, hash|
      hash[result.evaluator] = result.score
    end
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      input: input,
      output: output,
      ground_truth: ground_truth,
      scores: scores.transform_keys(&:name),
      results: results.map(&:to_h),
      messages: messages.map(&:to_h)
    }
  end
end
