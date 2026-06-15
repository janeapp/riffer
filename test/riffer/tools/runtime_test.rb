# frozen_string_literal: true

require "test_helper"

describe Riffer::Tools::Runtime do
  let(:weather_tool_class) do
    Class.new(Riffer::Tool) do
      identifier "weather_tool"
      description "Gets the weather"

      params do
        required :city, String
      end

      def call(context:, city:)
        text("Weather in #{city}: 20 degrees")
      end
    end
  end

  let(:slow_tool_class) do
    Class.new(Riffer::Tool) do
      identifier "slow_tool"
      description "A slow tool"
      timeout 0.01

      def call(context:, **)
        sleep 0.02
        text("done")
      end
    end
  end

  let(:tools) { [weather_tool_class] }
  let(:context) { nil }

  def make_tool_call(name:, arguments: "{}", call_id: "call_1")
    Riffer::Messages::Assistant::ToolCall.new(
      call_id: call_id,
      name: name,
      arguments: arguments
    )
  end

  def execute_single(runtime, tool_call, tools:, context:)
    results = runtime.execute([tool_call], tools: tools, context: context)
    results[0][1]
  end

  describe "#initialize" do
    it "raises NotImplementedError when instantiated directly" do
      expect {
        Riffer::Tools::Runtime.new(runner: Riffer::Runner::Sequential.new)
      }.must_raise NotImplementedError
    end
  end

  describe "#execute" do
    it "dispatches to correct tool and returns response" do
      runtime = Riffer::Tools::Runtime::Inline.new
      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')

      result = execute_single(runtime, tool_call, tools: tools, context: context)

      expect(result).must_be_instance_of Riffer::Tools::Response
      expect(result.content).must_equal "Weather in Toronto: 20 degrees"
      expect(result.success?).must_equal true
    end

    it "returns error response for unknown tool" do
      runtime = Riffer::Tools::Runtime::Inline.new
      tool_call = make_tool_call(name: "nonexistent", arguments: "{}")

      result = execute_single(runtime, tool_call, tools: tools, context: context)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :unknown_tool
      expect(result.content).must_match(/Unknown tool 'nonexistent'/)
    end

    it "returns error response for validation failure" do
      runtime = Riffer::Tools::Runtime::Inline.new
      tool_call = make_tool_call(name: "weather_tool", arguments: "{}")

      result = execute_single(runtime, tool_call, tools: tools, context: context)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :validation_error
    end

    it "returns error response for timeout" do
      runtime = Riffer::Tools::Runtime::Inline.new
      tool_call = make_tool_call(name: "slow_tool", arguments: "{}")

      result = execute_single(runtime, tool_call, tools: [slow_tool_class], context: context)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :timeout_error
    end

    it "returns error response for RuntimeError" do
      error_tool = Class.new(Riffer::Tool) do
        identifier "error_tool"
        description "Raises an error"

        def call(context:, **)
          raise "Something went wrong"
        end
      end

      runtime = Riffer::Tools::Runtime::Inline.new
      tool_call = make_tool_call(name: "error_tool", arguments: "{}")

      result = execute_single(runtime, tool_call, tools: [error_tool], context: context)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :execution_error
      expect(result.content).must_match(/Something went wrong/)
    end

    it "returns error response for ToolExecutionError" do
      error_tool = Class.new(Riffer::Tool) do
        identifier "tool_exec_error_tool"
        description "Raises a ToolExecutionError"

        def call(context:, **)
          raise Riffer::ToolExecutionError, "Expected failure"
        end
      end

      runtime = Riffer::Tools::Runtime::Inline.new
      tool_call = make_tool_call(name: "tool_exec_error_tool", arguments: "{}")

      result = execute_single(runtime, tool_call, tools: [error_tool], context: context)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :execution_error
      expect(result.content).must_equal "Expected failure"
    end

    it "propagates NoMethodError (programming bugs are not swallowed)" do
      buggy_tool = Class.new(Riffer::Tool) do
        identifier "buggy_tool"
        description "Has a bug"

        def call(context:, **)
          nil.nonexistent_method
        end
      end

      runtime = Riffer::Tools::Runtime::Inline.new
      tool_call = make_tool_call(name: "buggy_tool", arguments: "{}")

      expect {
        runtime.execute([tool_call], tools: [buggy_tool], context: context)
      }.must_raise NoMethodError
    end

    it "returns [tool_call, response] pairs in order" do
      runtime = Riffer::Tools::Runtime::Inline.new
      tc1 = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}', call_id: "1")
      tc2 = make_tool_call(name: "weather_tool", arguments: '{"city":"London"}', call_id: "2")

      results = runtime.execute([tc1, tc2], tools: tools, context: context)

      expect(results.length).must_equal 2
      expect(results[0][0]).must_equal tc1
      expect(results[0][1].content).must_equal "Weather in Toronto: 20 degrees"
      expect(results[1][0]).must_equal tc2
      expect(results[1][1].content).must_equal "Weather in London: 20 degrees"
    end
  end

  describe "#around_tool_call" do
    it "yields by default" do
      runtime = Riffer::Tools::Runtime::Inline.new
      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')

      results = runtime.execute([tool_call], tools: tools, context: context)

      expect(results[0][1].content).must_equal "Weather in Toronto: 20 degrees"
    end

    it "can be overridden in a subclass" do
      log = []
      runtime_class = Class.new(Riffer::Tools::Runtime::Inline) do
        define_method(:around_tool_call) do |tool_call, **, &block|
          log << "before:#{tool_call.name}"
          result = block.call
          log << "after:#{tool_call.name}"
          result
        end
      end

      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')
      runtime_class.new.execute([tool_call], tools: tools, context: context)

      expect(log).must_equal ["before:weather_tool", "after:weather_tool"]
    end

    it "is inherited by subclasses" do
      log = []
      parent = Class.new(Riffer::Tools::Runtime::Inline) do
        define_method(:around_tool_call) do |tool_call, **, &block|
          log << "parent"
          block.call
        end
      end

      child = Class.new(parent)
      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')
      child.new.execute([tool_call], tools: tools, context: context)

      expect(log).must_equal ["parent"]
    end

    it "allows subclass to override" do
      log = []
      parent = Class.new(Riffer::Tools::Runtime::Inline) do
        define_method(:around_tool_call) do |_, **, &block|
          log << "parent"
          block.call
        end
      end

      child = Class.new(parent) do
        define_method(:around_tool_call) do |_, **, &block|
          log << "child"
          block.call
        end
      end

      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')
      child.new.execute([tool_call], tools: tools, context: context)

      expect(log).must_equal ["child"]
    end

    it "forwards assistant_message to the hook" do
      seen = []
      runtime_class = Class.new(Riffer::Tools::Runtime::Inline) do
        define_method(:around_tool_call) do |_tool_call, context:, assistant_message: nil, &block|
          seen << assistant_message
          block.call
        end
      end

      assistant = Riffer::Messages::Assistant.new("here you go", tool_calls: [])
      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')
      runtime_class.new.execute([tool_call], tools: tools, context: context, assistant_message: assistant)

      expect(seen).must_equal [assistant]
    end

    it "defaults assistant_message to nil when not supplied" do
      seen = []
      runtime_class = Class.new(Riffer::Tools::Runtime::Inline) do
        define_method(:around_tool_call) do |_tool_call, context:, assistant_message: nil, &block|
          seen << assistant_message
          block.call
        end
      end

      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')
      runtime_class.new.execute([tool_call], tools: tools, context: context)

      expect(seen).must_equal [nil]
    end
  end

  describe "#dispatch_tool_call" do
    it "forwards assistant_message to overrides" do
      seen = []
      runtime_class = Class.new(Riffer::Tools::Runtime::Inline) do
        define_method(:dispatch_tool_call) do |_tool_call, tools:, context:, assistant_message: nil|
          seen << assistant_message
          Riffer::Tools::Response.text("ok")
        end
      end

      assistant = Riffer::Messages::Assistant.new("calling tool", tool_calls: [])
      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')
      runtime_class.new.execute([tool_call], tools: tools, context: context, assistant_message: assistant)

      expect(seen).must_equal [assistant]
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
      Riffer.config.tracing.tracer_provider = nil
    end

    let(:buggy_tool_class) do
      Class.new(Riffer::Tool) do
        identifier "buggy_tool"
        description "Has a bug"

        def call(context:, **)
          nil.nonexistent_method
        end
      end
    end

    let(:tool_call) { make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}') }

    let(:enriching_runtime_class) do
      Class.new(Riffer::Tools::Runtime::Inline) do
        define_method(:around_tool_call) do |_tool_call, **, &block|
          Riffer::Tracing.in_span("host_tool_work") { block.call }
        end
      end
    end

    let(:tool_class) do
      Class.new(Riffer::Tool) do
        description "Traced tool"
        def call(context:)
          text("done")
        end
      end.tap { |t| t.identifier("integration_tool") }
    end

    let(:agent_class_with_tools) do
      tc = tool_class
      Class.new(Riffer::Agent) do
        identifier "traced-agent"
        model "mock/riffer-1"
        uses_tools [tc]
      end
    end

    def tool_spans
      @exporter.finished_spans.select { |span| span.name.start_with?("execute_tool") }
    end

    def tool_span
      tool_spans.first
    end

    def assert_parents_under_host(runtime)
      tool_calls = 3.times.map { |i| make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}', call_id: "cid_#{i}") }

      Riffer::Tracing.in_span("host") do
        runtime.execute(tool_calls, tools: [weather_tool_class], context: nil)
      end

      host = @exporter.finished_spans.find { |span| span.name == "host" }
      spans = tool_spans
      expect(spans.length).must_equal 3
      spans.each do |span|
        expect(span.parent_span_id).must_equal host.span_id
        expect(span.trace_id).must_equal host.trace_id
      end
    end

    describe "span shape" do
      before do
        runtime = Riffer::Tools::Runtime::Inline.new
        tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}', call_id: "tc_42")
        runtime.execute([tool_call], tools: [weather_tool_class], context: nil)
      end

      it "names the span after the tool" do
        expect(tool_span.name).must_equal "execute_tool weather_tool"
      end

      it "marks the span as internal" do
        expect(tool_span.kind).must_equal :internal
      end

      it "sets the tool attributes" do
        attributes = tool_span.attributes.slice("gen_ai.operation.name", "gen_ai.tool.name", "gen_ai.tool.call.id")
        expect(attributes).must_equal({
          "gen_ai.operation.name" => "execute_tool",
          "gen_ai.tool.name" => "weather_tool",
          "gen_ai.tool.call.id" => "tc_42"
        })
      end

      it "leaves the span status unset on success" do
        expect(tool_span.status.code).must_equal OpenTelemetry::Trace::Status::UNSET
      end
    end

    describe "returned error responses" do
      before do
        runtime = Riffer::Tools::Runtime::Inline.new
        # Empty args fail validation, which dispatch turns into an error Response.
        tool_call = make_tool_call(name: "weather_tool", arguments: "{}")
        runtime.execute([tool_call], tools: [weather_tool_class], context: nil)
      end

      it "records error.type from the response error type" do
        expect(tool_span.attributes["error.type"]).must_equal "validation_error"
      end

      it "keeps the span status unset (handled outcome)" do
        expect(tool_span.status.code).must_equal OpenTelemetry::Trace::Status::UNSET
      end
    end

    describe "raised exceptions" do
      before do
        runtime = Riffer::Tools::Runtime::Inline.new
        tool_call = make_tool_call(name: "buggy_tool")
        begin
          runtime.execute([tool_call], tools: [buggy_tool_class], context: nil)
        rescue NoMethodError
        end
      end

      it "records error.type from the exception class" do
        expect(tool_span.attributes["error.type"]).must_equal "NoMethodError"
      end

      it "marks the span status as error" do
        expect(tool_span.status.code).must_equal OpenTelemetry::Trace::Status::ERROR
      end
    end

    it "omits arguments and result by default" do
      Riffer::Tools::Runtime::Inline.new.execute([tool_call], tools: [weather_tool_class], context: nil)
      expect(tool_span.attributes).wont_include "gen_ai.tool.call.arguments"
      expect(tool_span.attributes).wont_include "gen_ai.tool.call.result"
    end

    it "captures the raw arguments and result when enabled" do
      Riffer.config.tracing.capture_messages = true
      Riffer::Tools::Runtime::Inline.new.execute([tool_call], tools: [weather_tool_class], context: nil)
      expect(tool_span.attributes["gen_ai.tool.call.arguments"]).must_equal '{"city":"Toronto"}'
      expect(tool_span.attributes["gen_ai.tool.call.result"]).must_equal "Weather in Toronto: 20 degrees"
    end

    it "emits no span and still runs the tool" do
      Riffer.config.tracing.enabled = false
      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')

      results = Riffer::Tools::Runtime::Inline.new.execute([tool_call], tools: [weather_tool_class], context: nil)

      expect(@exporter.finished_spans).must_be_empty
      expect(results[0][1].content).must_equal "Weather in Toronto: 20 degrees"
    end

    it "parents to the active span under the Inline runtime" do
      assert_parents_under_host(Riffer::Tools::Runtime::Inline.new)
    end

    it "parents to the active span across the Threaded runtime's thread boundary" do
      assert_parents_under_host(Riffer::Tools::Runtime::Threaded.new(max_concurrency: 3))
    end

    it "parents to the active span across the Fibers runtime's fiber boundary" do
      assert_parents_under_host(Riffer::Tools::Runtime::Fibers.new)
    end

    it "nests host spans under execute_tool, which nests under the active span" do
      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')

      Riffer::Tracing.in_span("invoke_agent_stub") do
        enriching_runtime_class.new.execute([tool_call], tools: [weather_tool_class], context: nil)
      end

      agent = @exporter.finished_spans.find { |span| span.name == "invoke_agent_stub" }
      host = @exporter.finished_spans.find { |span| span.name == "host_tool_work" }

      expect(tool_span.parent_span_id).must_equal agent.span_id
      expect(host.parent_span_id).must_equal tool_span.span_id
      expect([tool_span.trace_id, host.trace_id].uniq).must_equal [agent.trace_id]
    end

    it "parents the execute_tool span to the invoke_agent span" do
      agent = agent_class_with_tools.new
      agent.provider.stub_response("", tool_calls: [{name: "integration_tool", arguments: "{}"}])
      agent.provider.stub_response("Done!")
      agent.generate("Call the tool")

      run_span = @exporter.finished_spans.find { |span| span.name.start_with?("invoke_agent") }
      expect(tool_span.name).must_equal "execute_tool integration_tool"
      expect(tool_span.parent_span_id).must_equal run_span.span_id
    end
  end
end

describe Riffer::Tools::Runtime::Inline do
  it "behaves identically to base" do
    runtime = Riffer::Tools::Runtime::Inline.new
    expect(runtime).must_be_kind_of Riffer::Tools::Runtime
  end

  it "executes tool calls sequentially" do
    weather_tool = Class.new(Riffer::Tool) do
      identifier "weather_tool"
      description "Gets the weather"

      params do
        required :city, String
      end

      def call(context:, city:)
        text("Weather in #{city}: 20 degrees")
      end
    end

    runtime = Riffer::Tools::Runtime::Inline.new
    tool_call = Riffer::Messages::Assistant::ToolCall.new(
      call_id: "cid_1", name: "weather_tool", arguments: '{"city":"Toronto"}'
    )

    results = runtime.execute([tool_call], tools: [weather_tool], context: nil)

    expect(results.length).must_equal 1
    expect(results[0][1].content).must_equal "Weather in Toronto: 20 degrees"
  end
end

describe Riffer::Tools::Runtime::Fibers do
  it "executes tool calls concurrently" do
    seen = []

    tracking_tool = Class.new(Riffer::Tool) do
      identifier "tracking_tool"
      description "Tracks fibers"

      define_method(:call) do |context:, **|
        seen << Fiber.current.object_id
        sleep 0.01
        text("done")
      end
    end

    runtime = Riffer::Tools::Runtime::Fibers.new
    tool_calls = 3.times.map do |i|
      Riffer::Messages::Assistant::ToolCall.new(
        call_id: "cid_#{i}", name: "tracking_tool", arguments: "{}"
      )
    end

    results = runtime.execute(tool_calls, tools: [tracking_tool], context: nil)

    expect(results.length).must_equal 3
    expect(seen.uniq.length).must_equal 3
  end
end

describe Riffer::Tools::Runtime::Threaded do
  it "executes tool calls in parallel" do
    thread_ids = Mutex.new
    seen = []

    tracking_tool = Class.new(Riffer::Tool) do
      identifier "tracking_tool"
      description "Tracks threads"

      define_method(:call) do |context:, **|
        thread_ids.synchronize { seen << Thread.current.object_id }
        sleep 0.01
        text("done")
      end
    end

    runtime = Riffer::Tools::Runtime::Threaded.new(max_concurrency: 3)
    tool_calls = 3.times.map do |i|
      Riffer::Messages::Assistant::ToolCall.new(
        call_id: "cid_#{i}", name: "tracking_tool", arguments: "{}"
      )
    end

    results = runtime.execute(tool_calls, tools: [tracking_tool], context: nil)

    expect(results.length).must_equal 3
    expect(seen.uniq.length).must_equal 3
  end
end
