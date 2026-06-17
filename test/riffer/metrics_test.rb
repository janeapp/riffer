# frozen_string_literal: true

require "test_helper"

describe Riffer::Metrics do
  before do
    Riffer.config.metrics.enabled = true
    Riffer.config.metrics.meter_provider = nil
  end

  after do
    Riffer.config.metrics.enabled = true
    Riffer.config.metrics.meter_provider = nil
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

    it "does not raise when the metrics SDK is not bundled" do
      skip "opentelemetry metrics is bundled" if METRICS_SDK_AVAILABLE
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
