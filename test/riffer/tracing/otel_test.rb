# frozen_string_literal: true

require "test_helper"

describe Riffer::Tracing::Otel do
  describe ".supported?" do
    it "rejects versions below 1.1" do
      expect(Riffer::Tracing::Otel.supported?(Gem::Version.new("1.0.0"))).must_equal false
    end

    it "accepts 1.1" do
      expect(Riffer::Tracing::Otel.supported?(Gem::Version.new("1.1.0"))).must_equal true
    end

    it "accepts later 1.x versions" do
      expect(Riffer::Tracing::Otel.supported?(Gem::Version.new("1.10.0"))).must_equal true
    end

    it "rejects 2.0" do
      expect(Riffer::Tracing::Otel.supported?(Gem::Version.new("2.0.0"))).must_equal false
    end
  end

  describe ".available?" do
    it "is true when opentelemetry is bundled" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE

      expect(Riffer::Tracing::Otel.available?).must_equal true
    end

    it "is false when opentelemetry is not bundled" do
      skip "opentelemetry is bundled" if OTEL_SDK_AVAILABLE

      expect(Riffer::Tracing::Otel.available?).must_equal false
    end
  end

  describe ".build" do
    it "returns a backend wrapping the global provider when opentelemetry is bundled" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE

      expect(Riffer::Tracing::Otel.build).must_be_instance_of Riffer::Tracing::Otel
    end

    it "returns nil when opentelemetry is not bundled" do
      skip "opentelemetry is bundled" if OTEL_SDK_AVAILABLE

      expect(Riffer::Tracing::Otel.build).must_be_nil
    end
  end
end
