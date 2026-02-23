# frozen_string_literal: true

# Context Relevance Evaluator
#
# Evaluates the utility of the ground truth context and detects gaps.
#
# Type: LLM judge
# higher_is_better: true
#
# Usage:
#
#   module RetrievalEvals
#     include Riffer::Evals::Profile
#     ai_evals do
#       metric ContextRelevanceEvaluator, min: 0.75
#     end
#   end
#
#   class MyAgent < Riffer::Agent
#     include RetrievalEvals
#     model "openai/gpt-4o"
#   end
#
#   result = MyAgent.run_eval(
#     input: "What are the health benefits of green tea?",
#     ground_truth: "Green tea is rich in catechins and may lower cholesterol."
#   )
#   result.passed?  # => true/false
#
class ContextRelevanceEvaluator < Riffer::Evals::Evaluator
  higher_is_better true

  instructions <<~TEXT
    Assess the utility and coverage of the ground truth context for answering the input question.

    Consider the following criteria:
    1. Does the ground truth provide sufficient information to answer the question?
    2. Are there important gaps in the context that would be needed for a complete answer?
    3. Is the context useful for generating an accurate response?
    4. Would additional context significantly improve the answer quality?

    Score between 0.0 and 1.0 where:
      - 1.0 = Fully relevant, covers everything needed
      - 0.7-0.9 = Mostly relevant with minor gaps
      - 0.4-0.6 = Partially relevant, notable information gaps
      - 0.1-0.3 = Marginally relevant, major gaps
      - 0.0 = Not relevant or useful for answering the question
  TEXT
end
