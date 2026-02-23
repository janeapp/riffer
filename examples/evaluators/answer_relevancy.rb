# frozen_string_literal: true

# Answer Relevancy Evaluator
#
# Evaluates how well a response addresses the input question.
#
# Type: LLM judge
# higher_is_better: true
#
# Usage:
#
#   module QualityEvals
#     include Riffer::Evals::Profile
#     ai_evals do
#       metric AnswerRelevancyEvaluator, min: 0.85
#     end
#   end
#
#   class MyAgent < Riffer::Agent
#     include QualityEvals
#     model "openai/gpt-4o"
#   end
#
#   result = MyAgent.run_eval(input: "What is Ruby?")
#   result.passed?  # => true/false
#
class AnswerRelevancyEvaluator < Riffer::Evals::Evaluator
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
