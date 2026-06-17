# frozen_string_literal: true
# rbs_inline: enabled

# No-op metrics backend, used when the OpenTelemetry metrics API is unavailable
# or metrics are disabled.
module Riffer::Metrics::Null # :nodoc: all
  extend self

  # Ignores the measurement; there is no meter without the OTEL metrics API.
  #--
  #: (String, Numeric, unit: String?, description: String?, attributes: Hash[String, untyped]?) -> void
  def record_histogram(name, value, unit:, description:, attributes:)
  end
end
