# frozen_string_literal: true

# Completeness Evaluator
#
# Evaluates whether the response includes all necessary information.
#
# Type: LLM judge
# higher_is_better: true
#
# Usage:
#
#   result = Riffer::Evals::EvaluatorRunner.run(
#     agent: MyAgent,
#     scenarios: [
#       { input: "What are the three primary colors?", ground_truth: "Red, blue, and yellow are the primary colors in traditional color theory." }
#     ],
#     evals: [CompletenessEvaluator]
#   )
#
#   result.scores  # => { CompletenessEvaluator => 0.9 }
#
class CompletenessEvaluator < Riffer::Evals::Evaluator
  higher_is_better true

  instructions <<~TEXT
    Assess whether the response includes all necessary information to fully answer the input.

    When ground truth is provided, use it as the reference for what constitutes a complete answer.

    Consider the following criteria:
    1. Are all key points from the ground truth covered?
    2. Are there important details or qualifications missing?
    3. Would the response leave the user needing to ask follow-up questions?
    4. Does the response address all parts of a multi-part question?

    Score between 0.0 and 1.0 where:
      - 1.0 = Fully complete, all necessary information included
      - 0.7-0.9 = Mostly complete with minor omissions
      - 0.4-0.6 = Partially complete, some key information missing
      - 0.1-0.3 = Mostly incomplete
      - 0.0 = Missing all key information
  TEXT
end
