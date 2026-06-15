# frozen_string_literal: true

require "test_helper"
require "json"

class ChatTracingExplodingProvider < Riffer::Providers::Mock
  private

  def execute_generate(params)
    raise Riffer::Error, "generate boom"
  end

  def execute_stream(params, yielder)
    yielder << Riffer::StreamEvents::TextDelta.new("partial")
    raise Riffer::Error, "stream boom"
  end
end

describe "Riffer::Providers::Base tracing" do
  before do
    skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
    Riffer.config.tracing.enabled = true
    @exporter = install_in_memory_tracer_provider
  end

  after do
    Riffer.config.tracing.enabled = true
    Riffer.config.tracing.capture_messages = false
    Riffer.config.tracing.tracer_provider = nil
  end

  let(:provider) { Riffer::Providers::Mock.new }

  def chat_span
    @exporter.finished_spans.find { |span| span.name.start_with?("chat") }
  end

  describe "#generate_text" do
    it "names the span chat with the model" do
      provider.generate_text(prompt: "Hello", model: "riffer-1")
      expect(chat_span.name).must_equal "chat riffer-1"
    end

    it "names the span chat when no model is given" do
      provider.generate_text(prompt: "Hello")
      expect(chat_span.name).must_equal "chat"
    end

    it "marks the span as a client span" do
      provider.generate_text(prompt: "Hello", model: "riffer-1")
      expect(chat_span.kind).must_equal :client
    end

    it "sets the request attributes" do
      provider.generate_text(prompt: "Hello", model: "riffer-1")
      attributes = chat_span.attributes.slice("gen_ai.operation.name", "gen_ai.provider.name", "gen_ai.request.model")
      expect(attributes).must_equal({
        "gen_ai.operation.name" => "chat",
        "gen_ai.provider.name" => "mock",
        "gen_ai.request.model" => "riffer-1"
      })
    end

    it "records token usage when reported" do
      provider.stub_response("Hi!", token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50, cache_read_tokens: 30))
      provider.generate_text(prompt: "Hello", model: "riffer-1")
      usage = chat_span.attributes.slice("gen_ai.usage.input_tokens", "gen_ai.usage.output_tokens", "gen_ai.usage.cache_read.input_tokens")
      expect(usage).must_equal({
        "gen_ai.usage.input_tokens" => 100,
        "gen_ai.usage.output_tokens" => 50,
        "gen_ai.usage.cache_read.input_tokens" => 30
      })
    end

    it "omits usage attributes when not reported" do
      provider.generate_text(prompt: "Hello", model: "riffer-1")
      expect(chat_span.attributes).wont_include "gen_ai.usage.input_tokens"
    end

    it "records the normalized finish reason" do
      provider.generate_text(prompt: "Hello", model: "riffer-1")
      expect(chat_span.attributes["gen_ai.response.finish_reasons"]).must_equal ["stop"]
    end

    it "records tool_calls as the finish reason when tool calls are present" do
      provider.stub_response("", tool_calls: [{name: "my_tool", arguments: "{}"}])
      provider.generate_text(prompt: "Hello", model: "riffer-1")
      expect(chat_span.attributes["gen_ai.response.finish_reasons"]).must_equal ["tool_calls"]
    end

    it "omits the raw finish reason when the provider reports none" do
      provider.generate_text(prompt: "Hello", model: "riffer-1")
      expect(chat_span.attributes).wont_include "riffer.finish_reason.raw"
    end

    it "stamps whitelisted request params" do
      provider.generate_text(prompt: "Hello", model: "riffer-1", temperature: 0.5, max_output_tokens: 128)
      params = chat_span.attributes.slice("gen_ai.request.temperature", "gen_ai.request.max_tokens")
      expect(params).must_equal({"gen_ai.request.temperature" => 0.5, "gen_ai.request.max_tokens" => 128})
    end

    it "keeps unknown options off the span" do
      provider.generate_text(prompt: "Hello", model: "riffer-1", custom_option: "secret")
      expect(chat_span.attributes.keys.grep(/custom_option/)).must_be_empty
    end

    it "keeps message content off the span by default" do
      provider.generate_text(prompt: "Hello", model: "riffer-1")
      expect(chat_span.attributes).wont_include "gen_ai.input.messages"
    end

    it "stamps error.type when the provider raises" do
      exploding = ChatTracingExplodingProvider.new
      expect { exploding.generate_text(prompt: "Hello", model: "riffer-1") }.must_raise(Riffer::Error)
      expect(chat_span.attributes["error.type"]).must_equal "Riffer::Error"
    end

    it "marks the span status as error when the provider raises" do
      exploding = ChatTracingExplodingProvider.new
      expect { exploding.generate_text(prompt: "Hello", model: "riffer-1") }.must_raise(Riffer::Error)
      expect(chat_span.status.code).must_equal OpenTelemetry::Trace::Status::ERROR
    end
  end

  describe "#generate_text content capture" do
    before { Riffer.config.tracing.capture_messages = true }

    it "captures input messages as semconv JSON" do
      provider.generate_text(prompt: "Hi", model: "riffer-1")
      messages = JSON.parse(chat_span.attributes["gen_ai.input.messages"])
      expect(messages).must_equal [{"role" => "user", "parts" => [{"type" => "text", "content" => "Hi"}]}]
    end

    it "captures system instructions separately from input messages" do
      provider.generate_text(system: "Be brief", prompt: "Hi", model: "riffer-1")
      instructions = JSON.parse(chat_span.attributes["gen_ai.system_instructions"])
      expect(instructions).must_equal [{"type" => "text", "content" => "Be brief"}]
    end

    it "captures the output message with its finish reason" do
      provider.stub_response("Hello!")
      provider.generate_text(prompt: "Hi", model: "riffer-1")
      output = JSON.parse(chat_span.attributes["gen_ai.output.messages"])
      expect(output).must_equal [{"role" => "assistant", "parts" => [{"type" => "text", "content" => "Hello!"}], "finish_reason" => "stop"}]
    end
  end

  describe "#stream_text" do
    it "emits no span before the enumerator is consumed" do
      provider.stream_text(prompt: "Hello", model: "riffer-1")
      expect(@exporter.finished_spans).must_be_empty
    end

    it "emits the chat span when the stream drains" do
      provider.stream_text(prompt: "Hello", model: "riffer-1").each { |_| }
      expect(chat_span.name).must_equal "chat riffer-1"
    end

    it "marks the span as a client span" do
      provider.stream_text(prompt: "Hello", model: "riffer-1").each { |_| }
      expect(chat_span.kind).must_equal :client
    end

    it "records token usage from the stream" do
      provider.stub_response("Hi!", token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50))
      provider.stream_text(prompt: "Hello", model: "riffer-1").each { |_| }
      usage = chat_span.attributes.slice("gen_ai.usage.input_tokens", "gen_ai.usage.output_tokens")
      expect(usage).must_equal({"gen_ai.usage.input_tokens" => 100, "gen_ai.usage.output_tokens" => 50})
    end

    it "records the finish reason from the stream" do
      provider.stream_text(prompt: "Hello", model: "riffer-1").each { |_| }
      expect(chat_span.attributes["gen_ai.response.finish_reasons"]).must_equal ["stop"]
    end

    it "parents the chat span to the trace active at the call" do
      enumerator = nil
      Riffer::Tracing.in_span("host") { enumerator = provider.stream_text(prompt: "Hello", model: "riffer-1") }
      enumerator.each { |_| }
      host = @exporter.finished_spans.find { |span| span.name == "host" }
      expect(chat_span.parent_span_id).must_equal host.span_id
    end

    it "captures streamed output when capture is on" do
      Riffer.config.tracing.capture_messages = true
      provider.stub_response("Hello there.")
      provider.stream_text(prompt: "Hi", model: "riffer-1").each { |_| }
      output = JSON.parse(chat_span.attributes["gen_ai.output.messages"])
      expect(output.dig(0, "parts", 0)).must_equal({"type" => "text", "content" => "Hello there."})
    end

    it "stamps error.type when the stream raises mid-flight" do
      exploding = ChatTracingExplodingProvider.new
      expect { exploding.stream_text(prompt: "Hello", model: "riffer-1").each { |_| } }.must_raise(Riffer::Error)
      expect(chat_span.attributes["error.type"]).must_equal "Riffer::Error"
    end
  end

  describe "agent integration" do
    let(:agent_class) do
      Class.new(Riffer::Agent) do
        identifier "chat-traced-agent"
        model "mock/riffer-1"
      end
    end

    it "nests the chat span under the run span" do
      agent_class.new.generate("Hello")
      run_span = @exporter.finished_spans.find { |span| span.name.start_with?("invoke_agent") }
      expect(chat_span.parent_span_id).must_equal run_span.span_id
    end

    it "nests the streamed chat span under the run span" do
      agent_class.new.stream("Hello").each { |_| }
      run_span = @exporter.finished_spans.find { |span| span.name.start_with?("invoke_agent") }
      expect(chat_span.parent_span_id).must_equal run_span.span_id
    end
  end

  describe "when tracing is disabled" do
    it "emits no spans" do
      Riffer.config.tracing.enabled = false
      provider.generate_text(prompt: "Hello", model: "riffer-1")
      expect(@exporter.finished_spans).must_be_empty
    end
  end
end
