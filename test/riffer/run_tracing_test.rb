# frozen_string_literal: true

require "test_helper"

class RunTracingBlockingInputGuardrail < Riffer::Guardrail
  def process_input(messages, context:)
    block("Input blocked")
  end
end

class RunTracingBlockingOutputGuardrail < Riffer::Guardrail
  def process_output(response, messages:, context:)
    block("Output blocked")
  end
end

describe Riffer::Agent::Run do
  before do
    skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
    Riffer.config.tracing.enabled = true
    @exporter = install_in_memory_tracer_provider
  end

  after do
    Riffer.config.tracing.enabled = true
    Riffer.config.tracing.tracer_provider = nil
  end

  let(:agent_class) do
    Class.new(Riffer::Agent) do
      identifier "traced-agent"
      model "mock/riffer-1"
    end
  end

  let(:tool_class) do
    Class.new(Riffer::Tool) do
      description "Traced tool"
      def call(context:)
        text("done")
      end
    end.tap { |t| t.identifier("run_tracing_tool") }
  end

  let(:agent_class_with_tools) do
    tc = tool_class
    Class.new(Riffer::Agent) do
      identifier "traced-agent"
      model "mock/riffer-1"
      uses_tools [tc]
    end
  end

  def run_span
    @exporter.finished_spans.find { |span| span.name.start_with?("invoke_agent") }
  end

  def generate_with_tool_loop(agent)
    agent.provider.stub_response(
      "",
      tool_calls: [{name: "run_tracing_tool", arguments: "{}"}],
      token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50)
    )
    agent.provider.stub_response("Done!", token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 150, output_tokens: 75))
    agent.generate("Call the tool")
  end

  describe "#generate" do
    it "names the span after the agent identifier" do
      agent_class.new.generate("Hello")
      expect(@exporter.finished_spans.map(&:name)).must_equal ["invoke_agent traced-agent"]
    end

    it "marks the span as internal" do
      agent_class.new.generate("Hello")
      expect(run_span.kind).must_equal :internal
    end

    it "sets the request attributes" do
      agent_class.new.generate("Hello")
      attributes = run_span.attributes.slice("gen_ai.operation.name", "gen_ai.agent.name", "gen_ai.provider.name", "gen_ai.request.model")
      expect(attributes).must_equal({
        "gen_ai.operation.name" => "invoke_agent",
        "gen_ai.agent.name" => "traced-agent",
        "gen_ai.provider.name" => "mock",
        "gen_ai.request.model" => "riffer-1"
      })
    end

    it "records the per-run step count across tool loops" do
      generate_with_tool_loop(agent_class_with_tools.new)
      expect(run_span.attributes["riffer.steps"]).must_equal 2
    end

    it "aggregates token usage across steps" do
      generate_with_tool_loop(agent_class_with_tools.new)
      usage = run_span.attributes.slice("gen_ai.usage.input_tokens", "gen_ai.usage.output_tokens")
      expect(usage).must_equal({"gen_ai.usage.input_tokens" => 250, "gen_ai.usage.output_tokens" => 125})
    end

    it "omits usage attributes when no call reports usage" do
      agent_class.new.generate("Hello")
      expect(run_span.attributes).wont_include "gen_ai.usage.input_tokens"
    end

    it "records cache token attributes when reported" do
      agent = agent_class.new
      agent.provider.stub_response("Hello!", token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50, cache_read_tokens: 30, cache_write_tokens: 10))
      agent.generate("Hello")
      cache = run_span.attributes.slice("gen_ai.usage.cache_read.input_tokens", "gen_ai.usage.cache_creation.input_tokens")
      expect(cache).must_equal({"gen_ai.usage.cache_read.input_tokens" => 30, "gen_ai.usage.cache_creation.input_tokens" => 10})
    end

    it "leaves the span status unset on success" do
      agent_class.new.generate("Hello")
      expect(run_span.status.code).must_equal OpenTelemetry::Trace::Status::UNSET
    end
  end

  describe "interrupts" do
    it "records the interrupt reason" do
      agent = agent_class.new
      agent.session.on_message { |msg| agent.interrupt!("approval needed") if msg.is_a?(Riffer::Messages::Assistant) }
      agent.generate("Hello")
      expect(run_span.attributes["riffer.interrupt.reason"]).must_equal "approval needed"
    end

    it "records the max steps interrupt reason" do
      tc = tool_class
      agent_with_max_steps = Class.new(Riffer::Agent) do
        identifier "traced-agent"
        model "mock/riffer-1"
        uses_tools [tc]
        max_steps 1
      end
      generate_with_tool_loop(agent_with_max_steps.new)
      expect(run_span.attributes["riffer.interrupt.reason"]).must_equal "max_steps"
    end

    it "keeps the span status unset on interrupts" do
      agent = agent_class.new
      agent.session.on_message { |msg| agent.interrupt!("approval needed") if msg.is_a?(Riffer::Messages::Assistant) }
      agent.generate("Hello")
      expect(run_span.status.code).must_equal OpenTelemetry::Trace::Status::UNSET
    end
  end

  describe "tripwires" do
    let(:agent_class_with_blocking_input) do
      klass = Class.new(Riffer::Agent) do
        identifier "traced-agent"
        model "mock/riffer-1"
      end
      klass.guardrail(:before, with: RunTracingBlockingInputGuardrail)
      klass
    end

    let(:agent_class_with_blocking_output) do
      klass = Class.new(Riffer::Agent) do
        identifier "traced-agent"
        model "mock/riffer-1"
      end
      klass.guardrail(:after, with: RunTracingBlockingOutputGuardrail)
      klass
    end

    it "records the tripwire guardrail" do
      agent_class_with_blocking_input.new.generate("Hello")
      expect(run_span.attributes["riffer.tripwire.guardrail"]).must_equal "RunTracingBlockingInputGuardrail"
    end

    it "records the tripwire reason" do
      agent_class_with_blocking_input.new.generate("Hello")
      expect(run_span.attributes["riffer.tripwire.reason"]).must_equal "Input blocked"
    end

    it "records the before phase" do
      agent_class_with_blocking_input.new.generate("Hello")
      expect(run_span.attributes["riffer.tripwire.phase"]).must_equal "before"
    end

    it "records the after phase" do
      agent_class_with_blocking_output.new.generate("Hello")
      expect(run_span.attributes["riffer.tripwire.phase"]).must_equal "after"
    end

    it "records zero steps when a before guardrail blocks" do
      agent_class_with_blocking_input.new.generate("Hello")
      expect(run_span.attributes["riffer.steps"]).must_equal 0
    end

    it "records usage from calls made before an after guardrail blocks" do
      agent = agent_class_with_blocking_output.new
      agent.provider.stub_response("Hello!", token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50))
      agent.generate("Hello")
      expect(run_span.attributes["gen_ai.usage.input_tokens"]).must_equal 100
    end

    it "keeps the span status unset when a tripwire fires" do
      agent_class_with_blocking_input.new.generate("Hello")
      expect(run_span.status.code).must_equal OpenTelemetry::Trace::Status::UNSET
    end
  end

  describe "errors" do
    def generate_with_raising_callback(agent)
      agent.session.on_message { raise "boom" }
      agent.generate("Hello")
    end

    it "re-raises errors from the run" do
      expect { generate_with_raising_callback(agent_class.new) }.must_raise RuntimeError
    end

    it "marks the span status as error when the run raises" do
      begin
        generate_with_raising_callback(agent_class.new)
      rescue RuntimeError
      end
      expect(run_span.status.code).must_equal OpenTelemetry::Trace::Status::ERROR
    end

    it "records the error type when the run raises" do
      begin
        generate_with_raising_callback(agent_class.new)
      rescue RuntimeError
      end
      expect(run_span.attributes["error.type"]).must_equal "RuntimeError"
    end
  end

  describe "#stream" do
    it "emits no span before the enumerator is consumed" do
      agent_class.new.stream("Hello")
      expect(@exporter.finished_spans).must_be_empty
    end

    it "emits the run span when the stream drains" do
      agent_class.new.stream("Hello").each { |_| }
      expect(@exporter.finished_spans.map(&:name)).must_equal ["invoke_agent traced-agent"]
    end

    it "parents the run span to the trace active at the stream call" do
      enumerator = nil
      Riffer::Tracing.in_span("host") { enumerator = agent_class.new.stream("Hello") }
      enumerator.each { |_| }
      host = @exporter.finished_spans.find { |span| span.name == "host" }
      expect(run_span.parent_span_id).must_equal host.span_id
    end

    it "aggregates streamed token usage" do
      agent = agent_class.new
      agent.provider.stub_response("Hello!", token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50))
      agent.stream("Hello").each { |_| }
      usage = run_span.attributes.slice("gen_ai.usage.input_tokens", "gen_ai.usage.output_tokens")
      expect(usage).must_equal({"gen_ai.usage.input_tokens" => 100, "gen_ai.usage.output_tokens" => 50})
    end
  end
end
