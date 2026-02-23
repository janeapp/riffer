# frozen_string_literal: true

# Tool Call Accuracy Evaluator
#
# Evaluates precision and recall of tool selection against expected tool calls.
#
# Type: Rule-based (no LLM call)
# higher_is_better: true
#
# Expects ground_truth to be a comma-separated list of expected tool names.
# Expects output to be a comma-separated list of actual tool names called.
#
# Usage:
#
#   evaluator = ToolCallAccuracyEvaluator.new
#   result = evaluator.evaluate(
#     input: "What's the weather in Paris?",
#     output: "get_weather,get_location",
#     ground_truth: "get_weather,get_location"
#   )
#   result.score  # => 1.0
#
#   # In an eval profile:
#   module ToolEvals
#     include Riffer::Evals::Profile
#     ai_evals do
#       metric ToolCallAccuracyEvaluator, min: 0.8
#     end
#   end
#
class ToolCallAccuracyEvaluator < Riffer::Evals::Evaluator
  higher_is_better true

  def evaluate(input:, output:, ground_truth: nil)
    return result(score: 1.0, reason: "No ground truth provided for comparison") unless ground_truth

    expected = parse_tool_names(ground_truth)
    actual = parse_tool_names(output)

    return result(score: 1.0, reason: "No tools expected and none called") if expected.empty? && actual.empty?
    return result(score: 0.0, reason: "Expected tools but none were called") if actual.empty?
    return result(score: 0.0, reason: "No tools expected but #{actual.size} were called") if expected.empty?

    true_positives = (expected & actual).size
    precision = true_positives.to_f / actual.size
    recall = true_positives.to_f / expected.size
    f1 = ((precision + recall) > 0) ? (2 * precision * recall / (precision + recall)) : 0.0

    result(
      score: f1.round(2),
      reason: "Precision: #{precision.round(2)}, Recall: #{recall.round(2)}, F1: #{f1.round(2)}",
      metadata: {
        expected: expected.to_a,
        actual: actual.to_a,
        precision: precision.round(2),
        recall: recall.round(2)
      }
    )
  end

  private

  def parse_tool_names(text)
    text.split(",").map(&:strip).reject(&:empty?).to_set
  end
end
