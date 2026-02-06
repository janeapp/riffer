# frozen_string_literal: true

require "json"

# Executes LLM-as-judge evaluations using the provider infrastructure.
#
# The Judge class handles calling an LLM to evaluate agent outputs
# and parsing the structured response.
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
  # The model string (provider/model format).
  #
  # Returns String.
  attr_reader :model

  # Initializes a new judge.
  #
  # model:: String - the model to use (provider/model format)
  # provider_options:: Hash - options passed to the provider
  def initialize(model:, provider_options: {})
    @model = model
    @provider_options = provider_options
  end

  # Evaluates using the configured LLM.
  #
  # messages:: Array - array of message hashes (alternative to system_prompt/user_prompt)
  # system_prompt:: String - the system prompt for the judge
  # user_prompt:: String - the user prompt containing the evaluation request
  #
  # Returns Hash with :score (Float) and :reason (String).
  #
  # Raises Riffer::ArgumentError if both messages and system_prompt/user_prompt are provided,
  # or if user_prompt is missing when messages is not provided.
  def evaluate(messages: nil, system_prompt: nil, user_prompt: nil)
    response = if messages
      raise Riffer::ArgumentError, "cannot provide both messages and system_prompt/user_prompt" if system_prompt || user_prompt
      provider_instance.generate_text(messages: messages, model: model_name)
    else
      raise Riffer::ArgumentError, "user_prompt is required when messages is not provided" unless user_prompt
      provider_instance.generate_text(system: system_prompt, prompt: user_prompt, model: model_name)
    end

    parse_response(response.content)
  end

  private

  def provider_instance
    @provider_instance ||= begin
      provider_class = Riffer::Providers::Repository.find(provider_name)
      raise Riffer::ArgumentError, "Provider not found: #{provider_name}" unless provider_class
      provider_class.new(**@provider_options)
    end
  end

  def provider_name
    @provider_name ||= @model.split("/", 2).first
  end

  def model_name
    @model_name ||= @model.split("/", 2).last
  end

  def parse_response(content)
    json_match = content.match(/\{[^{}]*"score"[^{}]*\}/m)
    raise Riffer::Error, "Invalid judge response: no JSON found" unless json_match

    parsed = JSON.parse(json_match[0])
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
