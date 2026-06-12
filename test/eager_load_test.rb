# frozen_string_literal: true

require "test_helper"

describe "eager loading" do
  # Catches class-level references to optional-dependency constants
  # (::OpenTelemetry in particular), which only fail when the gem is absent —
  # the no-OTEL CI lane runs this without opentelemetry bundled.
  it "eager loads every riffer constant" do
    Zeitwerk::Loader.eager_load_all
  end
end
