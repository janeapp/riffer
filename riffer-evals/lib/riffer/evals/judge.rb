# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Evals::Judge
  attr_reader :model #: String # @dynamic model
  attr_reader :identifier #: String # @dynamic identifier

  #--
  #: (model: String, ?identifier: String) -> void
  def initialize(model:, identifier: Riffer::Evals::Evaluator::DEFAULT_IDENTIFIER)
    @model = model
    @identifier = identifier
  end

  #--
  #: (instructions: String, input: String, output: String, ?ground_truth: String?) -> Hash[Symbol, untyped]
  def evaluate(instructions:, input:, output:, ground_truth: nil)
    agent = build_agent(build_system_message(instructions))
    response = agent.generate(
      build_user_message(input: input, output: output, ground_truth: ground_truth),
      tags: { kind: "judge" },
    )

    evaluation = response.structured_output
    raise Riffer::Error, "Invalid judge response: #{response.outcome.detail}" if evaluation.nil?

    { score: evaluation[:score], reason: evaluation[:reason], token_usage: response.token_usage }
  end

  private

  #--
  #: (String) -> Riffer::Agent
  def build_agent(system_message)
    judge_model = model
    judge_identifier = identifier
    agent_class = Class.new(Riffer::Agent) do
      model judge_model
      identifier judge_identifier
      instructions system_message
      structured_output do
        required :score, Float, description: "Evaluation score between 0.0 and 1.0"
        required :reason, String, description: "Brief explanation for the score"
      end
    end
    agent_class.new
  end

  #--
  #: (String) -> String
  def build_system_message(instructions)
    <<~SYSTEM.strip
      You are an evaluation assistant. Score the output based on the instructions below.

      #{instructions}

      Respond with your score and the reasoning behind it.
    SYSTEM
  end

  #--
  #: (input: String, output: String, ?ground_truth: String?) -> String
  def build_user_message(input:, output:, ground_truth: nil)
    parts = [] #: Array[String]
    parts << "## Input\n\n#{input}"
    parts << "## Output\n\n#{output}"
    parts << "## Ground Truth\n\n#{ground_truth}" if ground_truth
    parts.join("\n\n")
  end
end
