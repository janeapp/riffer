# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Evals::ScenarioResult
  attr_reader :input #: String # @dynamic input
  attr_reader :output #: String # @dynamic output
  attr_reader :ground_truth #: String? # @dynamic ground_truth
  attr_reader :results #: Array[Riffer::Evals::Result] # @dynamic results
  attr_reader :messages #: Array[Riffer::Messages::Base] # @dynamic messages
  attr_reader :token_usage #: Riffer::Providers::TokenUsage? # @dynamic token_usage

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

  #--
  #: () -> Hash[singleton(Riffer::Evals::Evaluator), Float]
  def scores
    acc = {} #: Hash[singleton(Riffer::Evals::Evaluator), Float]
    results.each_with_object(acc) do |result, hash|
      hash[result.evaluator] = result.score
    end
  end

  #--
  #: () -> Riffer::Providers::TokenUsage?
  def evaluator_token_usage
    results.filter_map(&:token_usage).reduce(:+)
  end

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
