# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Evals::ScenarioResult
  attr_reader :input #: String # @dynamic input
  # Nil when the agent raised.
  attr_reader :output #: String? # @dynamic output
  attr_reader :ground_truth #: (String | Hash[Symbol, untyped])? # @dynamic ground_truth
  attr_reader :results #: Array[Riffer::Evals::Result] # @dynamic results
  attr_reader :messages #: Array[Riffer::Messages::Base] # @dynamic messages
  attr_reader :token_usage #: Riffer::Providers::TokenUsage? # @dynamic token_usage
  attr_reader :outcome #: Riffer::Agent::Outcome? # @dynamic outcome
  attr_reader :structured_output #: Hash[Symbol, untyped]? # @dynamic structured_output
  # Seconds spent in the agent's generate call, excluding evaluators.
  attr_reader :latency #: Float? # @dynamic latency
  attr_reader :error #: StandardError? # @dynamic error

  #--
  #: (input: String, output: String?, ground_truth: (String | Hash[Symbol, untyped])?, results: Array[Riffer::Evals::Result], ?messages: Array[Riffer::Messages::Base], ?token_usage: Riffer::Providers::TokenUsage?, ?outcome: Riffer::Agent::Outcome?, ?structured_output: Hash[Symbol, untyped]?, ?latency: Float?, ?error: StandardError?) -> void
  def initialize(
    input:,
    output:,
    ground_truth:,
    results:,
    messages: [],
    token_usage: nil,
    outcome: nil,
    structured_output: nil,
    latency: nil,
    error: nil
  )
    @input = input
    @output = output
    @ground_truth = ground_truth
    @results = results
    @messages = messages
    @token_usage = token_usage
    @outcome = outcome
    @structured_output = structured_output
    @latency = latency
    @error = error
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
      outcome: outcome && { reason: outcome.reason, detail: outcome.detail },
      structured_output: structured_output,
      latency: latency,
      error: error && { class: error.class.name, message: error.message },
    }
  end
end
