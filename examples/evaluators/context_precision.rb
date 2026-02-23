# frozen_string_literal: true

# Context Precision Evaluator
#
# Evaluates the relevance and ranking quality of the provided ground truth context.
#
# Type: LLM judge
# higher_is_better: true
#
# Usage:
#
#   module RetrievalEvals
#     include Riffer::Evals::Profile
#     ai_evals do
#       metric ContextPrecisionEvaluator, min: 0.8
#     end
#   end
#
#   class MyAgent < Riffer::Agent
#     include RetrievalEvals
#     model "openai/gpt-4o"
#   end
#
#   result = MyAgent.run_eval(
#     input: "What is the capital of France?",
#     ground_truth: "Paris is the capital and most populous city of France."
#   )
#   result.passed?  # => true/false
#
class ContextPrecisionEvaluator < Riffer::Evals::Evaluator
  higher_is_better true

  instructions <<~TEXT
    Assess the precision and relevance of the ground truth context provided for answering the input.

    Consider the following criteria:
    1. Is the ground truth directly relevant to the question asked?
    2. Does the ground truth contain the information needed to answer correctly?
    3. Is there minimal noise or irrelevant information in the ground truth?
    4. Is the most relevant information prominent rather than buried?

    Score between 0.0 and 1.0 where:
      - 1.0 = Perfectly precise, all context is highly relevant
      - 0.7-0.9 = Mostly precise with minor irrelevant content
      - 0.4-0.6 = Mixed precision, significant irrelevant content
      - 0.1-0.3 = Low precision, mostly irrelevant context
      - 0.0 = Completely irrelevant context
  TEXT
end
