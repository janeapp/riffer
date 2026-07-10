# frozen_string_literal: true

require "test_helper"
require "json"

class BaseTestNamedProvider < Riffer::Providers::Base
end

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

class DeclaredKeyProvider < Riffer::Providers::Mock
  private

  def pricing_key(model)
    "jane/#{model}"
  end
end

describe Riffer::Providers::Base do
  let(:provider) { Riffer::Providers::Base.new }

  describe ".skills_adapter" do
    it "returns MarkdownAdapter by default" do
      expect(Riffer::Providers::Base.skills_adapter).must_equal Riffer::Skills::MarkdownAdapter
    end

    it "ignores the model argument" do
      expect(Riffer::Providers::Base.skills_adapter("anything/at-all")).must_equal Riffer::Skills::MarkdownAdapter
    end
  end

  describe ".semconv_provider_name" do
    it "derives the snake_cased class name by default" do
      expect(BaseTestNamedProvider.semconv_provider_name).must_equal "base_test_named_provider"
    end

    it "falls back to unknown for anonymous classes" do
      expect(Class.new(Riffer::Providers::Base).semconv_provider_name).must_equal "unknown"
    end
  end

  describe "#pricing_key" do
    before { Riffer.instance_variable_set(:@config, Riffer::Config.new) }
    after { Riffer.instance_variable_set(:@config, Riffer::Config.new) }

    it "resolves rates against the overridden declared id, independent of the concrete class" do
      Riffer.config.pricing.set("jane/claude-sonnet-4-6", input: 3.0, output: 15.0)
      provider = DeclaredKeyProvider.new
      provider.stub_response("hi", token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 1_000_000, output_tokens: 1_000_000))
      message = provider.generate_text(prompt: "x", model: "claude-sonnet-4-6")
      expect(message.token_usage.cost).must_equal 18.0
    end
  end

  describe "#generate_text" do
    it "raises NotImplementedError when hook methods not implemented" do
      error = expect { provider.generate_text(prompt: "Hello") }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #build_request_params"
    end

    it "raises ArgumentError when no prompt or messages provided" do
      error = expect { provider.generate_text }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "prompt is required when messages is not provided"
    end

    it "raises ArgumentError when both prompt and messages provided" do
      error = expect do
        provider.generate_text(prompt: "Hello", messages: [{role: "user", content: "Hi"}])
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "cannot provide both prompt and messages"
    end

    it "raises ArgumentError when both system and messages provided" do
      error = expect do
        provider.generate_text(system: "You are helpful", messages: [{role: "user", content: "Hi"}])
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "cannot provide both system and messages"
    end

    it "raises ArgumentError when messages has no user message" do
      error = expect do
        provider.generate_text(messages: [{role: "system", content: "You are helpful"}])
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "messages must include at least one user message"
    end
  end

  describe "#stream_text" do
    it "raises NotImplementedError when hook methods not implemented" do
      error = expect { provider.stream_text(prompt: "Hello") }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #build_request_params"
    end
  end

  describe "#normalize_messages" do
    it "converts prompt to User message" do
      result = provider.send(:normalize_messages, prompt: "Hello", system: nil, messages: nil)
      expect(result.all? { |msg| msg.is_a?(Riffer::Messages::Base) }).must_equal true
    end

    it "converts system and prompt to System and User messages" do
      result = provider.send(:normalize_messages, prompt: "Hello", system: "Be helpful", messages: nil)
      expect(result.all? { |msg| msg.is_a?(Riffer::Messages::Base) }).must_equal true
    end

    describe "with message objects" do
      let(:messages) do
        [
          Riffer::Messages::User.new("Hello"),
          Riffer::Messages::Assistant.new("Hi there")
        ]
      end

      it "preserves message objects when provided" do
        result = provider.send(:normalize_messages, prompt: nil, system: nil, messages: messages)
        expect(result).must_equal messages
      end
    end
  end

  describe "#merge_consecutive_messages" do
    it "passes through alternating messages unchanged" do
      messages = [
        Riffer::Messages::User.new("Hello"),
        Riffer::Messages::Assistant.new("Hi"),
        Riffer::Messages::User.new("How are you?")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 3
    end

    it "passes through a single message unchanged" do
      messages = [Riffer::Messages::User.new("Hello")]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 1
      expect(result.first.content).must_equal "Hello"
    end

    it "merges consecutive user messages" do
      messages = [
        Riffer::Messages::User.new("First"),
        Riffer::Messages::User.new("Second")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 1
      expect(result.first).must_be_instance_of Riffer::Messages::User
      expect(result.first.content).must_equal "First\n\nSecond"
    end

    it "combines files when merging consecutive user messages" do
      file_a = Riffer::Messages::FilePart.new(data: "abc", media_type: "image/png")
      file_b = Riffer::Messages::FilePart.new(data: "def", media_type: "image/jpeg")
      messages = [
        Riffer::Messages::User.new("With image", files: [file_a]),
        Riffer::Messages::User.new("Another image", files: [file_b])
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 1
      expect(result.first.files).must_equal [file_a, file_b]
    end

    it "merges consecutive system messages" do
      messages = [
        Riffer::Messages::System.new("Rule one"),
        Riffer::Messages::System.new("Rule two")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 1
      expect(result.first).must_be_instance_of Riffer::Messages::System
      expect(result.first.content).must_equal "Rule one\n\nRule two"
    end

    it "merges consecutive assistant messages and combines tool calls" do
      tc = Riffer::Messages::Assistant::ToolCall.new(call_id: "1", name: "foo", arguments: "{}")
      messages = [
        Riffer::Messages::Assistant.new("Part one", tool_calls: [tc]),
        Riffer::Messages::Assistant.new("Part two")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 1
      expect(result.first).must_be_instance_of Riffer::Messages::Assistant
      expect(result.first.content).must_equal "Part one\n\nPart two"
      expect(result.first.tool_calls).must_equal [tc]
    end

    it "does not merge consecutive tool messages" do
      messages = [
        Riffer::Messages::Tool.new("Result A", tool_call_id: "1", name: "foo"),
        Riffer::Messages::Tool.new("Result B", tool_call_id: "2", name: "bar")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 2
    end

    it "only merges consecutive runs in a mixed sequence" do
      messages = [
        Riffer::Messages::System.new("System"),
        Riffer::Messages::User.new("Context"),
        Riffer::Messages::User.new("Question"),
        Riffer::Messages::Assistant.new("Answer"),
        Riffer::Messages::Tool.new("Result", tool_call_id: "1", name: "t"),
        Riffer::Messages::Tool.new("Result 2", tool_call_id: "2", name: "t2")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 5
      expect(result[0]).must_be_instance_of Riffer::Messages::System
      expect(result[1]).must_be_instance_of Riffer::Messages::User
      expect(result[1].content).must_equal "Context\n\nQuestion"
      expect(result[2]).must_be_instance_of Riffer::Messages::Assistant
      expect(result[3]).must_be_instance_of Riffer::Messages::Tool
      expect(result[4]).must_be_instance_of Riffer::Messages::Tool
    end

    it "merges context message with user message" do
      messages = [
        Riffer::Messages::System.new("You are helpful"),
        Riffer::Messages::User.new("Here is some context about the project"),
        Riffer::Messages::User.new("What does this code do?")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 2
      expect(result[0]).must_be_instance_of Riffer::Messages::System
      expect(result[1]).must_be_instance_of Riffer::Messages::User
      expect(result[1].content).must_equal "Here is some context about the project\n\nWhat does this code do?"
    end
  end

  describe "tracing" do
    before do
      skip "opentelemetry is not bundled" unless OTEL_SDK_AVAILABLE
      Riffer.config.tracing.enabled = true
      @exporter = install_in_memory_tracer_provider
    end

    after do
      Riffer.config.tracing.enabled = true
      Riffer.config.tracing.capture_messages = false
      Riffer.config.tracing.backend = nil
    end

    let(:provider) { Riffer::Providers::Mock.new }

    let(:agent_class) do
      Class.new(Riffer::Agent) do
        identifier "chat-traced-agent"
        model "mock/riffer-1"
      end
    end

    def chat_span
      @exporter.finished_spans.find { |span| span.name.start_with?("chat") }
    end

    it "names the span chat with the model" do
      provider.generate_text(prompt: "Hello", model: "riffer-1")
      expect(chat_span.name).must_equal "chat riffer-1"
    end

    it "names the span chat when no model is given" do
      provider.generate_text(prompt: "Hello")
      expect(chat_span.name).must_equal "chat"
    end

    it "marks the generate_text span as a client span" do
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

    it "stamps the cost when the call carries one" do
      provider.stub_response("Hi!", token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50, cost: 0.0021))
      provider.generate_text(prompt: "Hello", model: "riffer-1")
      expect(chat_span.attributes["riffer.cost"]).must_equal 0.0021
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

    it "emits no span before the enumerator is consumed" do
      provider.stream_text(prompt: "Hello", model: "riffer-1")
      expect(@exporter.finished_spans).must_be_empty
    end

    it "emits the chat span when the stream drains" do
      provider.stream_text(prompt: "Hello", model: "riffer-1").each { |_| }
      expect(chat_span.name).must_equal "chat riffer-1"
    end

    it "marks the stream_text span as a client span" do
      provider.stream_text(prompt: "Hello", model: "riffer-1").each { |_| }
      expect(chat_span.kind).must_equal :client
    end

    it "records token usage from the stream" do
      provider.stub_response("Hi!", token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50))
      provider.stream_text(prompt: "Hello", model: "riffer-1").each { |_| }
      usage = chat_span.attributes.slice("gen_ai.usage.input_tokens", "gen_ai.usage.output_tokens")
      expect(usage).must_equal({"gen_ai.usage.input_tokens" => 100, "gen_ai.usage.output_tokens" => 50})
    end

    it "stamps the cost from the stream" do
      provider.stub_response("Hi!", token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50, cost: 0.0021))
      provider.stream_text(prompt: "Hello", model: "riffer-1").each { |_| }
      expect(chat_span.attributes["riffer.cost"]).must_equal 0.0021
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

    it "emits no spans" do
      Riffer.config.tracing.enabled = false
      provider.generate_text(prompt: "Hello", model: "riffer-1")
      expect(@exporter.finished_spans).must_be_empty
    end
  end
end
