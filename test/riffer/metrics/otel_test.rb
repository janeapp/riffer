# frozen_string_literal: true

require "test_helper"

describe Riffer::Metrics::Otel do
  describe ".supported?" do
    it "rejects versions below 0.2" do
      expect(Riffer::Metrics::Otel.supported?(Gem::Version.new("0.1.0"))).must_equal false
    end

    it "accepts 0.2" do
      expect(Riffer::Metrics::Otel.supported?(Gem::Version.new("0.2.0"))).must_equal true
    end

    it "accepts later 0.x versions" do
      expect(Riffer::Metrics::Otel.supported?(Gem::Version.new("0.6.0"))).must_equal true
    end

    it "rejects 1.0" do
      expect(Riffer::Metrics::Otel.supported?(Gem::Version.new("1.0.0"))).must_equal false
    end
  end

  describe ".available?" do
    it "is true when the opentelemetry metrics API is bundled" do
      skip "opentelemetry metrics API is not bundled" unless METRICS_API_AVAILABLE
      expect(Riffer::Metrics::Otel.available?).must_equal true
    end

    it "is false when the opentelemetry metrics API is not bundled" do
      skip "opentelemetry metrics API is bundled" if METRICS_API_AVAILABLE
      expect(Riffer::Metrics::Otel.available?).must_equal false
    end
  end

  describe ".build" do
    it "returns a backend when the opentelemetry metrics API is bundled" do
      skip "opentelemetry metrics API is not bundled" unless METRICS_API_AVAILABLE
      expect(Riffer::Metrics::Otel.build(provider: nil)).must_be_instance_of Riffer::Metrics::Otel
    end

    it "returns nil when the opentelemetry metrics API is not bundled" do
      skip "opentelemetry metrics API is bundled" if METRICS_API_AVAILABLE
      expect(Riffer::Metrics::Otel.build(provider: nil)).must_be_nil
    end
  end
end
