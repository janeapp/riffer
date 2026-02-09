# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Executes LLM-as-judge evaluations using the provider infrastructure.
#
# The Judge class handles calling an LLM to evaluate agent outputs
# and parsing the structured response. It uses tool calling internally
# to get guaranteed structured output from the judge model.
#
#   judge = Riffer::Evals::Judge.new(model: "anthropic/claude-opus-4-5-20251101")
#   result = judge.evaluate(
#     system_prompt: "You are an evaluation assistant...",
#     user_prompt: "Evaluate this response..."
#   )
#   result[:score]  # => 0.85
#   result[:reason] # => "The response is relevant..."
#
class Riffer::Evals::Judge
  # Internal tool for structured evaluation output.
  class EvaluationTool < Riffer::Tool
    identifier "evaluation"
    description "Submit your evaluation score and reasoning"

    params do
      required :score, Float, description: "Evaluation score between 0.0 and 1.0"
      required :reason, String, description: "Brief explanation for the score"
    end

    #: context: Hash[Symbol, untyped]?
    #: score: Float
    #: reason: String
    #: return: Riffer::Tools::Response
    def call(context:, score:, reason:)
      json({score: score, reason: reason})
    end
  end

  #: @provider_options: Hash[Symbol, untyped]
  #: @provider_instance: Riffer::Providers::Base?
  #: @provider_name: String?
  #: @model_name: String?

  # The model string (provider/model format).
  attr_reader :model #: String

  # Initializes a new judge.
  #
  #: model: String -- the model to use (provider/model format)
  #: provider_options: Hash[Symbol, untyped] -- options passed to the provider
  #: return: void
  def initialize(model:, provider_options: {})
    provider_name, model_name = model.split("/", 2)
    unless [provider_name, model_name].all? { |part| part.is_a?(String) && !part.strip.empty? }
      raise Riffer::ArgumentError, "Invalid model string: #{model}"
    end

    @model = model
    @provider_options = provider_options
  end

  # Evaluates using the configured LLM.
  #
  # Raises Riffer::ArgumentError if both messages and system_prompt/user_prompt are provided,
  # or if user_prompt is missing when messages is not provided.
  #
  #: messages: Array[Hash[Symbol, untyped]]? -- array of message hashes
  #: system_prompt: String? -- the system prompt for the judge
  #: user_prompt: String? -- the user prompt containing the evaluation request
  #: return: Hash[Symbol, untyped]
  def evaluate(messages: nil, system_prompt: nil, user_prompt: nil)
    response = if messages
      raise Riffer::ArgumentError, "cannot provide both messages and system_prompt/user_prompt" if system_prompt || user_prompt
      provider_instance.generate_text(messages: messages, model: model_name, tools: [EvaluationTool])
    else
      raise Riffer::ArgumentError, "user_prompt is required when messages is not provided" unless user_prompt
      provider_instance.generate_text(system: system_prompt, prompt: user_prompt, model: model_name, tools: [EvaluationTool])
    end

    parse_tool_response(response)
  end

  private

  #: return: Riffer::Providers::Base
  def provider_instance
    @provider_instance ||= begin
      provider_class = Riffer::Providers::Repository.find(provider_name)
      raise Riffer::ArgumentError, "Provider not found: #{provider_name}" unless provider_class
      provider_class.new(**@provider_options)
    end
  end

  #: return: String
  def provider_name
    @provider_name ||= @model.split("/", 2).first
  end

  #: return: String
  def model_name
    @model_name ||= @model.split("/", 2).last
  end

  #: response: Riffer::Messages::Assistant
  #: return: Hash[Symbol, untyped]
  def parse_tool_response(response)
    tool_call = response.tool_calls.first
    raise Riffer::Error, "Invalid judge response: no tool call found" unless tool_call

    parsed = JSON.parse(tool_call[:arguments])
    score = parsed["score"]
    reason = parsed["reason"]

    raise Riffer::Error, "Invalid judge response: missing score" if score.nil?

    {
      score: score.to_f,
      reason: reason
    }
  rescue JSON::ParserError => e
    raise Riffer::Error, "Invalid judge response: #{e.message}"
  end
end
