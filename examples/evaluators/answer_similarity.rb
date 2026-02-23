# frozen_string_literal: true

# Answer Similarity Evaluator
#
# Evaluates the semantic similarity between the response and a ground truth answer.
#
# Type: LLM judge
# higher_is_better: true
#
# Usage:
#
#   module SimilarityEvals
#     include Riffer::Evals::Profile
#     ai_evals do
#       metric AnswerSimilarityEvaluator, min: 0.8
#     end
#   end
#
#   class MyAgent < Riffer::Agent
#     include SimilarityEvals
#     model "openai/gpt-4o"
#   end
#
#   result = MyAgent.run_eval(
#     input: "What is the capital of France?",
#     ground_truth: "The capital of France is Paris."
#   )
#   result.passed?  # => true/false
#
class AnswerSimilarityEvaluator < Riffer::Evals::Evaluator
  higher_is_better true

  instructions <<~TEXT
    Assess how semantically similar the response is to the provided ground truth.

    Focus on meaning rather than exact wording:
    1. Do both convey the same core information?
    2. Are the key facts and claims equivalent?
    3. Is the level of detail comparable?
    4. Are there any contradictions between the two?

    Score between 0.0 and 1.0 where:
      - 1.0 = Semantically identical, same meaning expressed
      - 0.7-0.9 = Very similar with minor differences in detail
      - 0.4-0.6 = Partially similar, some overlapping content
      - 0.1-0.3 = Mostly different in meaning
      - 0.0 = Completely different or contradictory
  TEXT
end
