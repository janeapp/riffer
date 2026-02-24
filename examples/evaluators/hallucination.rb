# frozen_string_literal: true

# Hallucination Evaluator
#
# Evaluates the presence of unsupported claims relative to the provided ground truth.
#
# Type: LLM judge
# higher_is_better: false (lower scores = fewer hallucinations = better)
#
# Usage:
#
#   result = Riffer::Evals::EvaluatorRunner.run(
#     agent: MyAgent,
#     scenarios: [
#       { input: "Summarize this article about Ruby.", ground_truth: "Ruby was created in 1995 by Yukihiro Matsumoto. It prioritizes developer happiness." }
#     ],
#     evals: [HallucinationEvaluator]
#   )
#
#   result.scores  # => { HallucinationEvaluator => 0.1 }
#
class HallucinationEvaluator < Riffer::Evals::Evaluator
  higher_is_better false

  instructions <<~TEXT
    Assess the degree to which the response contains claims not supported by the provided ground truth.

    The ground truth represents the factual basis against which the response should be checked.

    Consider the following criteria:
    1. Does the response make claims not present in the ground truth?
    2. Does the response fabricate specific details (names, dates, statistics)?
    3. Does the response extrapolate beyond what the ground truth supports?
    4. Does the response present opinions as facts?

    Score between 0.0 and 1.0 where:
      - 0.0 = No hallucinations, every claim is supported
      - 0.1-0.3 = Minor hallucinations or slight embellishments
      - 0.4-0.6 = Moderate hallucinations, some fabricated details
      - 0.7-0.9 = Significant hallucinations, many unsupported claims
      - 1.0 = Entirely hallucinated, no grounding in the source
  TEXT
end
