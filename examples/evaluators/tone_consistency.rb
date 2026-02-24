# frozen_string_literal: true

# Tone Consistency Evaluator
#
# Evaluates whether the response maintains a consistent tone, formality, and style.
#
# Type: LLM judge
# higher_is_better: true
#
# Usage:
#
#   result = Riffer::Evals::EvaluatorRunner.run(
#     agent: MyAgent,
#     scenarios: [{ input: "Explain quantum computing in a professional tone." }],
#     evals: [ToneConsistencyEvaluator]
#   )
#
#   result.scores  # => { ToneConsistencyEvaluator => 0.9 }
#
class ToneConsistencyEvaluator < Riffer::Evals::Evaluator
  higher_is_better true

  instructions <<~TEXT
    Assess the consistency of tone, formality, and style throughout the response.

    Consider the following criteria:
    1. Is the formality level consistent throughout the response?
    2. Does the tone match what was requested or implied by the input?
    3. Are there jarring shifts in register or style?
    4. Is the vocabulary consistent with the chosen tone?

    When ground truth is provided, use it as a reference for the expected tone.

    Score between 0.0 and 1.0 where:
      - 1.0 = Perfectly consistent tone throughout
      - 0.7-0.9 = Mostly consistent with minor shifts
      - 0.4-0.6 = Noticeable inconsistencies in tone
      - 0.1-0.3 = Frequently shifting or inappropriate tone
      - 0.0 = Completely inconsistent or inappropriate tone
  TEXT
end
