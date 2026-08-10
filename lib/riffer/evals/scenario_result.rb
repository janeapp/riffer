# frozen_string_literal: true
# rbs_inline: enabled

# Represents the result of evaluating a single scenario.
class Riffer::Evals::ScenarioResult
  # The input that was evaluated.
  attr_reader :input #: String

  # The agent output for this scenario.
  attr_reader :output #: String

  # The ground truth used during evaluation.
  attr_reader :ground_truth #: String?

  # Individual evaluation results.
  attr_reader :results #: Array[Riffer::Evals::Result]

  # The full message history from the agent conversation.
  attr_reader :messages #: Array[Riffer::Messages::Base]

  # Token usage the agent under test spent generating this scenario's output.
  attr_reader :token_usage #: Riffer::Providers::TokenUsage?

  #--
  #: (input: String, output: String, ground_truth: String?, results: Array[Riffer::Evals::Result], ?messages: Array[Riffer::Messages::Base], ?token_usage: Riffer::Providers::TokenUsage?) -> void
  def initialize(input:, output:, ground_truth:, results:, messages: [], token_usage: nil)
    @input = input
    @output = output
    @ground_truth = ground_truth
    @results = results
    @messages = messages
    @token_usage = token_usage
  end

  # Returns scores keyed by evaluator class.
  #
  #--
  #: () -> Hash[singleton(Riffer::Evals::Evaluator), Float]
  def scores
    acc = {} #: Hash[singleton(Riffer::Evals::Evaluator), Float]
    results.each_with_object(acc) do |result, hash|
      hash[result.evaluator] = result.score
    end
  end

  # Returns the summed token usage across this scenario's LLM-as-judge
  # evaluators, or nil when none reported usage.
  #
  #--
  #: () -> Riffer::Providers::TokenUsage?
  def evaluator_token_usage
    results.map(&:token_usage).compact.reduce(:+)
  end

  # Returns a hash representation of the scenario result.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      input: input,
      output: output,
      ground_truth: ground_truth,
      scores: scores.transform_keys(&:name),
      results: results.map(&:to_h),
      messages: messages.map(&:to_h),
      token_usage: token_usage&.to_h,
      evaluator_token_usage: evaluator_token_usage&.to_h,
    }
  end
end
