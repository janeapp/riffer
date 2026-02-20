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
  higher_is_better true

  instructions <<~TEXT
    Assess how well the response addresses the given input/question.

    Consider the following criteria:
    1. Does the response directly address what was asked?
    2. Is the response on-topic and relevant?
    3. Does the response provide the type of information requested?
    4. Does the response avoid going off on tangents?

    Score between 0.0 and 1.0 where:
      - 1.0 = Perfectly relevant, directly addresses the question
      - 0.7-0.9 = Mostly relevant with minor tangents
      - 0.4-0.6 = Partially relevant, some off-topic content
      - 0.1-0.3 = Mostly irrelevant
      - 0.0 = Completely irrelevant
  TEXT
end
