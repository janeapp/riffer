# frozen_string_literal: true

class PromptAlignmentEvaluator < Riffer::Evals::Evaluator
  higher_is_better true

  instructions <<~TEXT
    Assess how well the response aligns with the explicit and implicit requirements of the input prompt.

    Consider the following criteria:
    1. Does the response follow the format requested (e.g., list, paragraph, code)?
    2. Does the response respect constraints (e.g., length, tone, audience)?
    3. Does the response address the specific task described?
    4. Does the response follow any role or persona instructions?

    When ground truth is provided, use it as a reference for the expected alignment.

    Score between 0.0 and 1.0 where:
      - 1.0 = Perfectly aligned with all prompt requirements
      - 0.7-0.9 = Mostly aligned with minor deviations
      - 0.4-0.6 = Partially aligned, some requirements missed
      - 0.1-0.3 = Mostly misaligned
      - 0.0 = Completely ignores prompt requirements
  TEXT
end
