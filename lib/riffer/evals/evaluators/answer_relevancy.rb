# frozen_string_literal: true
# rbs_inline: enabled

# Evaluates how well a response addresses the input question.
#
# Uses LLM-as-judge to assess whether the response is relevant,
# on-topic, and directly addresses what was asked.
#
#   evaluator = Riffer::Evals::Evaluators::AnswerRelevancy.new
#   result = evaluator.evaluate(
#     input: "What is the capital of France?",
#     output: "The capital of France is Paris."
#   )
#   result.score  # => 0.95
#
class Riffer::Evals::Evaluators::AnswerRelevancy < Riffer::Evals::Evaluator
  description "Evaluates how well the response addresses the input question"
  higher_is_better true

  SYSTEM_PROMPT = <<~PROMPT #: String
    You are an evaluation assistant that assesses answer relevancy.

    Your task is to evaluate how well a response addresses the given input/question.

    Consider the following criteria:
    1. Does the response directly address what was asked?
    2. Is the response on-topic and relevant?
    3. Does the response provide the type of information requested?
    4. Does the response avoid going off on tangents?

    Use the evaluation tool to submit your score and reasoning. The score should be
    a float between 0.0 and 1.0 where:
      - 1.0 = Perfectly relevant, directly addresses the question
      - 0.7-0.9 = Mostly relevant with minor tangents
      - 0.4-0.6 = Partially relevant, some off-topic content
      - 0.1-0.3 = Mostly irrelevant
      - 0.0 = Completely irrelevant
  PROMPT

  #: (input: String, output: String, ?context: Hash[Symbol, untyped]?) -> Riffer::Evals::Result
  def evaluate(input:, output:, context: nil)
    user_prompt = build_user_prompt(input: input, output: output)
    evaluation = judge.evaluate(system_prompt: SYSTEM_PROMPT, user_prompt: user_prompt)
    result(score: evaluation[:score], reason: evaluation[:reason])
  end

  private

  #: (input: String, output: String) -> String
  def build_user_prompt(input:, output:)
    <<~PROMPT
      Input/Question:
      #{input}

      Response to evaluate:
      #{output}
    PROMPT
  end
end
