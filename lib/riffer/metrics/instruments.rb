# frozen_string_literal: true
# rbs_inline: enabled

# The catalog of metric instruments riffer records. Each handle is a constant
# that resolves its backend at record time, so it survives a meter-provider swap
# or a runtime +enabled+ flip.
module Riffer::Metrics::Instruments # :nodoc: all
  OPERATION_DURATION = Riffer::Metrics.create_histogram(
    "gen_ai.client.operation.duration",
    unit: "s",
    description: "Duration of GenAI client operations"
  ) #: Riffer::Metrics::Histogram

  TOKEN_USAGE = Riffer::Metrics.create_histogram(
    "gen_ai.client.token.usage",
    unit: "{token}",
    description: "Number of input and output tokens used in GenAI operations"
  ) #: Riffer::Metrics::Histogram

  COST = Riffer::Metrics.create_histogram(
    "riffer.gen_ai.cost",
    unit: "USD",
    description: "Cost of GenAI client operations in USD"
  ) #: Riffer::Metrics::Histogram

  GUARDRAIL_DURATION = Riffer::Metrics.create_histogram(
    "riffer.guardrail.duration",
    unit: "s",
    description: "Duration of guardrail execution"
  ) #: Riffer::Metrics::Histogram
end
