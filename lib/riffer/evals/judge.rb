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
#     instructions: "Assess answer relevancy...",
#     input: "What is Ruby?",
#     output: "Ruby is a programming language."
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

    #: (context: Hash[Symbol, untyped]?, score: Float, reason: String) -> Riffer::Tools::Response
    def call(context:, score:, reason:)
      json({score: score, reason: reason})
    end
  end

  # The model string (provider/model format).
  attr_reader :model #: String

  # Initializes a new judge.
  #
  #: (model: String, ?provider_options: Hash[Symbol, untyped]) -> void
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
  # Composes system and user messages from the semantic fields:
  # +instructions+ - evaluation criteria and scoring rubric.
  # +input+ - the original input/question.
  # +output+ - the agent's response to evaluate.
  # +ground_truth+ - optional reference answer for comparison.
  #
  #: (instructions: String, input: String, output: String, ?ground_truth: String?) -> Hash[Symbol, untyped]
  def evaluate(instructions:, input:, output:, ground_truth: nil)
    system_message = build_system_message(instructions)
    user_message = build_user_message(input: input, output: output, ground_truth: ground_truth)

    response = provider_instance.generate_text(
      system: system_message,
      prompt: user_message,
      model: model_name,
      tools: [EvaluationTool]
    )

    parse_tool_response(response)
  end

  private

  #: (String) -> String
  def build_system_message(instructions)
    <<~SYSTEM.strip
      You are an evaluation assistant. Score the output based on the instructions below.

      #{instructions}

      Use the evaluation tool to submit your score and reasoning.
    SYSTEM
  end

  #: (input: String, output: String, ?ground_truth: String?) -> String
  def build_user_message(input:, output:, ground_truth: nil)
    parts = []
    parts << "## Input\n\n#{input}"
    parts << "## Output\n\n#{output}"
    parts << "## Ground Truth\n\n#{ground_truth}" if ground_truth
    parts.join("\n\n")
  end

  #: () -> Riffer::Providers::Base
  def provider_instance
    @provider_instance ||= begin
      provider_class = Riffer::Providers::Repository.find(provider_name)
      raise Riffer::ArgumentError, "Provider not found: #{provider_name}" unless provider_class
      provider_class.new(**@provider_options)
    end
  end

  #: () -> String
  def provider_name
    @provider_name ||= @model.split("/", 2).first
  end

  #: () -> String
  def model_name
    @model_name ||= @model.split("/", 2).last
  end

  #: (Riffer::Messages::Assistant) -> Hash[Symbol, untyped]
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
