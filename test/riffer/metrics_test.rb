# frozen_string_literal: true

require "test_helper"

class FakeMetricsBackend
  attr_reader :records

  def initialize
    @records = []
  end

  def record_histogram(name, value, unit:, description:, attributes:)
    @records << {name: name, value: value, unit: unit, description: description, attributes: attributes}
  end
end

describe Riffer::Metrics do
  before do
    Riffer.config.metrics.enabled = true
    Riffer.config.metrics.backend = nil
  end

  after do
    Riffer.config.metrics.enabled = true
    Riffer.config.metrics.backend = nil
  end

  describe "#create_histogram" do
    it "returns a histogram handle" do
      expect(Riffer::Metrics.create_histogram("riffer.test")).must_be_instance_of Riffer::Metrics::Histogram
    end
  end

  describe "#record_histogram" do
    it "records a value against an in-memory meter provider" do
      skip "opentelemetry metrics is not bundled" unless METRICS_SDK_AVAILABLE
      exporter = install_in_memory_meter_provider
      Riffer::Metrics.record_histogram("riffer.test", 0.5)
      exporter.pull
      expect(exporter.metric_snapshots.first.data_points.first.sum).must_equal 0.5
    end

    it "records under the named instrument" do
      skip "opentelemetry metrics is not bundled" unless METRICS_SDK_AVAILABLE
      exporter = install_in_memory_meter_provider
      Riffer::Metrics.record_histogram("riffer.test", 0.5)
      exporter.pull
      expect(exporter.metric_snapshots.map(&:name)).must_equal ["riffer.test"]
    end

    it "records the given attributes" do
      skip "opentelemetry metrics is not bundled" unless METRICS_SDK_AVAILABLE
      exporter = install_in_memory_meter_provider
      Riffer::Metrics.record_histogram("riffer.test", 0.5, attributes: {"gen_ai.operation.name" => "chat"})
      exporter.pull
      expect(exporter.metric_snapshots.first.data_points.first.attributes).must_equal({"gen_ai.operation.name" => "chat"})
    end

    it "records the unit and description onto the instrument" do
      skip "opentelemetry metrics is not bundled" unless METRICS_SDK_AVAILABLE
      exporter = install_in_memory_meter_provider
      Riffer::Metrics.record_histogram("riffer.test", 0.5, unit: "s", description: "Test latency")
      exporter.pull
      snapshot = exporter.metric_snapshots.first
      expect([snapshot.unit, snapshot.description]).must_equal ["s", "Test latency"]
    end

    it "stamps the riffer instrumentation scope" do
      skip "opentelemetry metrics is not bundled" unless METRICS_SDK_AVAILABLE
      exporter = install_in_memory_meter_provider
      Riffer::Metrics.record_histogram("riffer.test", 0.5)
      exporter.pull
      scope = exporter.metric_snapshots.first.instrumentation_scope
      expect([scope.name, scope.version]).must_equal ["riffer", Riffer::VERSION]
    end

    it "reuses one instrument across records of the same name" do
      skip "opentelemetry metrics is not bundled" unless METRICS_SDK_AVAILABLE
      exporter = install_in_memory_meter_provider
      Riffer::Metrics.record_histogram("riffer.test", 0.5)
      Riffer::Metrics.record_histogram("riffer.test", 1.5)
      exporter.pull
      expect(exporter.metric_snapshots.first.data_points.first.sum).must_equal 2.0
    end

    it "records nothing when metrics are disabled" do
      skip "opentelemetry metrics is not bundled" unless METRICS_SDK_AVAILABLE
      exporter = install_in_memory_meter_provider
      Riffer.config.metrics.enabled = false
      Riffer::Metrics.record_histogram("riffer.test", 0.5)
      exporter.pull
      expect(exporter.metric_snapshots).must_be_empty
    end

    it "does not raise when no backend is configured" do
      Riffer::Metrics.record_histogram("riffer.test", 0.5)
    end
  end

  describe Riffer::Metrics::Histogram do
    it "records through a held handle" do
      skip "opentelemetry metrics is not bundled" unless METRICS_SDK_AVAILABLE
      exporter = install_in_memory_meter_provider
      histogram = Riffer::Metrics.create_histogram("riffer.test", unit: "s")
      histogram.record(0.5, attributes: {"gen_ai.operation.name" => "chat"})
      exporter.pull
      expect(exporter.metric_snapshots.first.data_points.first.sum).must_equal 0.5
    end

    it "keeps recording through a handle held across a provider swap" do
      skip "opentelemetry metrics is not bundled" unless METRICS_SDK_AVAILABLE
      histogram = Riffer::Metrics.create_histogram("riffer.test", unit: "s")
      first_exporter = install_in_memory_meter_provider
      histogram.record(0.5)
      second_exporter = install_in_memory_meter_provider
      histogram.record(1.5)
      first_exporter.pull
      second_exporter.pull
      sums = [first_exporter, second_exporter].map { |e| e.metric_snapshots.first.data_points.first.sum }
      expect(sums).must_equal [0.5, 1.5]
    end
  end

  describe "consumer-supplied backend" do
    it "routes records to the configured backend" do
      backend = FakeMetricsBackend.new
      Riffer.config.metrics.backend = backend
      Riffer::Metrics.record_histogram("riffer.test", 0.5)
      expect(backend.records.map { |record| record[:name] }).must_equal ["riffer.test"]
    end

    it "forwards the value, unit, description, and attributes" do
      backend = FakeMetricsBackend.new
      Riffer.config.metrics.backend = backend
      Riffer::Metrics.record_histogram("riffer.test", 0.5, unit: "s", description: "Test latency", attributes: {"k" => "v"})
      expect(backend.records.first).must_equal({name: "riffer.test", value: 0.5, unit: "s", description: "Test latency", attributes: {"k" => "v"}})
    end

    it "records nothing through the backend when metrics are disabled" do
      backend = FakeMetricsBackend.new
      Riffer.config.metrics.backend = backend
      Riffer.config.metrics.enabled = false
      Riffer::Metrics.record_histogram("riffer.test", 0.5)
      expect(backend.records).must_be_empty
    end
  end

  describe "#recording?" do
    it "is true when a consumer backend is configured" do
      Riffer.config.metrics.backend = FakeMetricsBackend.new
      expect(Riffer::Metrics.recording?).must_equal true
    end

    it "is false when metrics are disabled even with a backend configured" do
      Riffer.config.metrics.backend = FakeMetricsBackend.new
      Riffer.config.metrics.enabled = false
      expect(Riffer::Metrics.recording?).must_equal false
    end

    it "is false when no backend is configured" do
      expect(Riffer::Metrics.recording?).must_equal false
    end

    it "is true when the OTEL backend is configured" do
      skip "opentelemetry metrics is not bundled" unless METRICS_SDK_AVAILABLE
      install_in_memory_meter_provider
      expect(Riffer::Metrics.recording?).must_equal true
    end
  end

  describe "#reset!" do
    it "returns without error" do
      Riffer::Metrics.reset!
    end

    it "re-resolves the backend when the provider changes" do
      skip "opentelemetry metrics is not bundled" unless METRICS_SDK_AVAILABLE
      first_exporter = install_in_memory_meter_provider
      Riffer::Metrics.record_histogram("riffer.test", 0.5)
      second_exporter = install_in_memory_meter_provider
      Riffer::Metrics.record_histogram("riffer.test", 1.5)
      first_exporter.pull
      second_exporter.pull
      sums = [first_exporter, second_exporter].map { |e| e.metric_snapshots.first.data_points.first.sum }
      expect(sums).must_equal [0.5, 1.5]
    end
  end
end
