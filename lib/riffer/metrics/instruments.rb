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
end
