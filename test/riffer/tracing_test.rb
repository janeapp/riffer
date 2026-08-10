# frozen_string_literal: true

require "test_helper"

class FakeTracingBackend
  Span = Struct.new(:attributes) do
    def set_attribute(key, value) = attributes[key] = value

    def add_event(_name, attributes: nil) = nil

    def record_exception(_exception) = nil

    def error!(_description = "") = nil

    def recording? = true
  end

  attr_reader :opened, :context_calls

  def initialize
    @opened = []
    @context_calls = 0
  end

  def in_span(name, attributes: nil, kind: :internal)
    @opened << name
    yield Span.new({})
  end

  def current_context = :fake_context

  def with_context(_context)
    @context_calls += 1
    yield
  end
end

describe Riffer::Tracing do
  before do
    Riffer.config.tracing.enabled = true
    Riffer.config.tracing.backend = nil
  end

  after do
    Riffer.config.tracing.enabled = true
    Riffer.config.tracing.backend = nil
  end

  describe "#in_span" do
    it "returns the block's value" do
      result = Riffer::Tracing.in_span("test") { :value }

      expect(result).must_equal :value
    end

    it "yields the no-op span when tracing is disabled" do
      Riffer.config.tracing.enabled = false
      yielded = nil
      Riffer::Tracing.in_span("test") { |span| yielded = span }

      expect(yielded).must_be_same_as Riffer::Tracing::NoOp::SPAN
    end

    it "yields the no-op span when no backend is configured" do
      yielded = nil
      Riffer::Tracing.in_span("test") { |span| yielded = span }

      expect(yielded).must_be_same_as Riffer::Tracing::NoOp::SPAN
    end

    it "exports a span with the given name" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      Riffer::Tracing.in_span("invoke_agent test") {}

      expect(exporter.finished_spans.map(&:name)).must_equal ["invoke_agent test"]
    end

    it "exports the given attributes" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      Riffer::Tracing.in_span("test", attributes: { "gen_ai.operation.name" => "chat" }) {}

      expect(exporter.finished_spans.first.attributes).must_equal({ "gen_ai.operation.name" => "chat" })
    end

    it "exports the given span kind" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      Riffer::Tracing.in_span("test", kind: :client) {}

      expect(exporter.finished_spans.first.kind).must_equal :client
    end

    it "stamps the riffer instrumentation scope" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      Riffer::Tracing.in_span("test") {}
      scope = exporter.finished_spans.first.instrumentation_scope

      expect([scope.name, scope.version]).must_equal ["riffer", Riffer::VERSION]
    end

    it "nests spans opened inside an open span" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      Riffer::Tracing.in_span("parent") { Riffer::Tracing.in_span("child") {} }
      child, parent = exporter.finished_spans

      expect(child.parent_span_id).must_equal parent.span_id
    end

    it "yields a recording span when an SDK provider is wired" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      install_in_memory_tracer_provider
      recording = nil
      Riffer::Tracing.in_span("test") { |span| recording = span.recording? }

      expect(recording).must_equal true
    end

    it "re-raises errors raised in the block" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      install_in_memory_tracer_provider

      expect { Riffer::Tracing.in_span("test") { raise Riffer::Error, "boom" } }.must_raise Riffer::Error
    end

    it "records an error status when the block raises" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      begin
        Riffer::Tracing.in_span("test") { raise Riffer::Error, "boom" }
      rescue Riffer::Error
        # swallow the raise — the recorded span is the subject under test
      end

      expect(exporter.finished_spans.first.status.code).must_equal OpenTelemetry::Trace::Status::ERROR
    end

    it "records an error status from the span's error! method" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      Riffer::Tracing.in_span("test") { |span| span.error!("tripwire") }

      expect(exporter.finished_spans.first.status.code).must_equal OpenTelemetry::Trace::Status::ERROR
    end

    it "skips spans opened while disabled mid-process" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      Riffer::Tracing.in_span("before") {}
      Riffer.config.tracing.enabled = false
      Riffer::Tracing.in_span("dark") {}
      Riffer.config.tracing.enabled = true
      Riffer::Tracing.in_span("after") {}

      expect(exporter.finished_spans.map(&:name)).must_equal %w[before after]
    end
  end

  describe "#record_usage" do
    it "stamps the gen_ai.usage attributes onto the span" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      usage = Riffer::Providers::TokenUsage.new(
        input_tokens: 100,
        output_tokens: 50,
        cache_read_tokens: 30,
        cache_write_tokens: 10,
      )
      Riffer::Tracing.in_span("test") { |span| Riffer::Tracing.record_usage(span, usage) }

      expect(exporter.finished_spans.first.attributes).must_equal(
        {
          "gen_ai.usage.input_tokens" => 100,
          "gen_ai.usage.output_tokens" => 50,
          "gen_ai.usage.cache_read.input_tokens" => 30,
          "gen_ai.usage.cache_creation.input_tokens" => 10,
        },
      )
    end

    it "stamps nothing when usage is nil" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      Riffer::Tracing.in_span("test") { |span| Riffer::Tracing.record_usage(span, nil) }

      expect(exporter.finished_spans.first.attributes).must_equal({})
    end

    it "stamps riffer.cost when the usage carries a cost" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      usage = Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50, cost: 0.0123)
      Riffer::Tracing.in_span("test") { |span| Riffer::Tracing.record_usage(span, usage) }

      expect(exporter.finished_spans.first.attributes["riffer.cost"]).must_equal 0.0123
    end

    it "stamps a zero cost rather than treating it as absent" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      usage = Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50, cost: 0.0)
      Riffer::Tracing.in_span("test") { |span| Riffer::Tracing.record_usage(span, usage) }

      expect(exporter.finished_spans.first.attributes["riffer.cost"]).must_equal 0.0
    end

    it "omits riffer.cost when the usage carries no cost" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      usage = Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      Riffer::Tracing.in_span("test") { |span| Riffer::Tracing.record_usage(span, usage) }

      expect(exporter.finished_spans.first.attributes).wont_include "riffer.cost"
    end
  end

  describe "#current_context" do
    it "returns nil when tracing is disabled" do
      Riffer.config.tracing.enabled = false

      expect(Riffer::Tracing.current_context).must_be_nil
    end

    it "returns nil when no backend is configured" do
      expect(Riffer::Tracing.current_context).must_be_nil
    end
  end

  describe "#with_context" do
    it "returns the block's value" do
      result = Riffer::Tracing.with_context(nil) { :value }

      expect(result).must_equal :value
    end

    it "passes a nil context through" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      install_in_memory_tracer_provider
      result = Riffer::Tracing.with_context(nil) { :value }

      expect(result).must_equal :value
    end

    it "parents spans across an enumerator fiber via a captured context" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      enumerator = nil
      Riffer::Tracing.in_span("parent") do
        context = Riffer::Tracing.current_context
        enumerator = Enumerator.new do |yielder|
          Riffer::Tracing.with_context(context) do
            Riffer::Tracing.in_span("child") { yielder << :done }
          end
        end
      end
      enumerator.to_a
      parent = exporter.finished_spans.find { |span| span.name == "parent" }
      child = exporter.finished_spans.find { |span| span.name == "child" }

      expect(child.parent_span_id).must_equal parent.span_id
    end

    it "parents spans across threads via a captured context" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      exporter = install_in_memory_tracer_provider
      Riffer::Tracing.in_span("parent") do
        context = Riffer::Tracing.current_context
        Thread.new do
          Riffer::Tracing.with_context(context) do
            Riffer::Tracing.in_span("child") {}
          end
        end.join
      end
      parent = exporter.finished_spans.find { |span| span.name == "parent" }
      child = exporter.finished_spans.find { |span| span.name == "child" }

      expect(child.parent_span_id).must_equal parent.span_id
    end
  end

  describe "consumer-supplied backend" do
    it "routes spans to the configured backend" do
      backend = FakeTracingBackend.new
      Riffer.config.tracing.backend = backend
      Riffer::Tracing.in_span("custom") {}

      expect(backend.opened).must_equal ["custom"]
    end

    it "yields the backend's span to the block" do
      Riffer.config.tracing.backend = FakeTracingBackend.new
      yielded = nil
      Riffer::Tracing.in_span("custom") { |span| yielded = span }

      expect(yielded).must_be_instance_of FakeTracingBackend::Span
    end

    it "returns the block's value through the backend" do
      Riffer.config.tracing.backend = FakeTracingBackend.new
      result = Riffer::Tracing.in_span("custom") { :value }

      expect(result).must_equal :value
    end

    it "delegates current_context to the backend" do
      Riffer.config.tracing.backend = FakeTracingBackend.new

      expect(Riffer::Tracing.current_context).must_equal :fake_context
    end

    it "delegates with_context to the backend" do
      backend = FakeTracingBackend.new
      Riffer.config.tracing.backend = backend
      Riffer::Tracing.with_context(:ctx) {}

      expect(backend.context_calls).must_equal 1
    end

    it "yields the no-op span when tracing is disabled, bypassing the backend" do
      backend = FakeTracingBackend.new
      Riffer.config.tracing.backend = backend
      Riffer.config.tracing.enabled = false
      yielded = nil
      Riffer::Tracing.in_span("custom") { |span| yielded = span }

      expect(yielded).must_be_same_as Riffer::Tracing::NoOp::SPAN
    end
  end

  describe "#reset!" do
    it "returns without error" do
      Riffer::Tracing.reset!
    end

    it "re-resolves the backend when the provider changes" do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      first_exporter = install_in_memory_tracer_provider
      Riffer::Tracing.in_span("first") {}
      second_exporter = install_in_memory_tracer_provider
      Riffer::Tracing.in_span("second") {}

      span_names = [first_exporter, second_exporter].map { |e| e.finished_spans.map(&:name) }

      expect(span_names).must_equal [["first"], ["second"]]
    end
  end
end
