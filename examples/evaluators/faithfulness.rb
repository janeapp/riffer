# frozen_string_literal: true

# Faithfulness Evaluator
#
# Evaluates the accuracy of the response relative to the provided ground truth context.
#
# Type: LLM judge
# higher_is_better: true
#
# Usage:
#
#   module FaithfulnessEvals
#     include Riffer::Evals::Profile
#     ai_evals do
#       metric FaithfulnessEvaluator, min: 0.9
#     end
#   end
#
#   class MyAgent < Riffer::Agent
#     include FaithfulnessEvals
#     model "openai/gpt-4o"
#   end
#
#   result = MyAgent.run_eval(
#     input: "What year was Ruby created?",
#     ground_truth: "Ruby was created in 1995 by Yukihiro Matsumoto."
#   )
#   result.passed?  # => true/false
#
class FaithfulnessEvaluator < Riffer::Evals::Evaluator
  higher_is_better true

  instructions <<~TEXT
    Assess how faithfully the response reflects the information in the provided ground truth.

    The ground truth represents the source material the response should be grounded in.

    Consider the following criteria:
    1. Are all claims in the response supported by the ground truth?
    2. Does the response avoid adding information not present in the ground truth?
    3. Are facts and figures accurately reproduced?
    4. Does the response maintain the meaning and intent of the source material?

    Score between 0.0 and 1.0 where:
      - 1.0 = Perfectly faithful, all claims supported by ground truth
      - 0.7-0.9 = Mostly faithful with minor unsupported additions
      - 0.4-0.6 = Partially faithful, mix of supported and unsupported claims
      - 0.1-0.3 = Mostly unfaithful to the ground truth
      - 0.0 = Completely unfaithful, contradicts the ground truth
  TEXT
end
