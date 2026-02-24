# frozen_string_literal: true

# Keyword Coverage Evaluator
#
# Evaluates keyword intersection coverage between the response and ground truth.
#
# Type: Rule-based (no LLM call)
# higher_is_better: true
#
# Usage:
#
#   result = Riffer::Evals::EvaluatorRunner.run(
#     agent: MyAgent,
#     scenarios: [
#       { input: "What is Ruby?", ground_truth: "Ruby is a dynamic, open-source programming language focused on simplicity and productivity." }
#     ],
#     evals: [KeywordCoverageEvaluator]
#   )
#
#   result.scores  # => { KeywordCoverageEvaluator => 0.7 }
#
class KeywordCoverageEvaluator < Riffer::Evals::Evaluator
  STOP_WORDS = %w[
    a an the is are was were be been being have has had do does did
    will would shall should may might can could of in to for on with
    at by from as into through during before after above below between
    out off over under again further then once and but or nor not so
    yet both either neither each every all any few more most other some
    such no only own same than too very that this these those it its
  ].freeze

  higher_is_better true

  def evaluate(input:, output:, ground_truth: nil)
    raise ArgumentError, "ground_truth is required for KeywordCoverageEvaluator" unless ground_truth

    truth_keywords = extract_keywords(ground_truth)
    return result(score: 1.0, reason: "No keywords found in ground truth") if truth_keywords.empty?

    output_keywords = extract_keywords(output)
    covered = truth_keywords & output_keywords
    score = covered.size.to_f / truth_keywords.size

    result(
      score: score.round(2),
      reason: "Covered #{covered.size}/#{truth_keywords.size} keywords from ground truth",
      metadata: {covered: covered.to_a, missing: (truth_keywords - output_keywords).to_a}
    )
  end

  private

  def extract_keywords(text)
    text
      .downcase
      .gsub(/[^a-z0-9\s]/, "")
      .split
      .reject { |w| STOP_WORDS.include?(w) || w.length < 2 }
      .to_set
  end
end
