# frozen_string_literal: true

require "test_helper"

describe Riffer::ToolRuntime do
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

  def make_tool_call(name:, arguments:, id: "call_1")
    Riffer::Messages::Assistant::ToolCall.new(
      id: id,
      call_id: "call_id_#{id}",
      name: name,
      arguments: arguments
    )
  end

  describe "#call" do
    it "dispatches to correct tool and returns response" do
      runtime = Riffer::ToolRuntime.new
      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')

      result = runtime.call(tool_call, tools: tools, context: context)

      expect(result).must_be_instance_of Riffer::Tools::Response
      expect(result.content).must_equal "Weather in Toronto: 20 degrees"
      expect(result.success?).must_equal true
    end

    it "returns error response for unknown tool" do
      runtime = Riffer::ToolRuntime.new
      tool_call = make_tool_call(name: "nonexistent", arguments: "{}")

      result = runtime.call(tool_call, tools: tools, context: context)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :unknown_tool
      expect(result.content).must_match(/Unknown tool 'nonexistent'/)
    end

    it "returns error response for validation failure" do
      runtime = Riffer::ToolRuntime.new
      tool_call = make_tool_call(name: "weather_tool", arguments: "{}")

      result = runtime.call(tool_call, tools: tools, context: context)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :validation_error
    end

    it "returns error response for timeout" do
      runtime = Riffer::ToolRuntime.new
      tool_call = make_tool_call(name: "slow_tool", arguments: "{}")

      result = runtime.call(tool_call, tools: [slow_tool_class], context: context)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :timeout_error
    end

    it "returns error response for execution error" do
      error_tool = Class.new(Riffer::Tool) do
        identifier "error_tool"
        description "Raises an error"

        def call(context:, **)
          raise "Something went wrong"
        end
      end

      runtime = Riffer::ToolRuntime.new
      tool_call = make_tool_call(name: "error_tool", arguments: "{}")

      result = runtime.call(tool_call, tools: [error_tool], context: context)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :execution_error
      expect(result.content).must_match(/Something went wrong/)
    end
  end

  describe "#execute" do
    it "returns [tool_call, response] pairs in order" do
      runtime = Riffer::ToolRuntime.new
      tc1 = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}', id: "1")
      tc2 = make_tool_call(name: "weather_tool", arguments: '{"city":"London"}', id: "2")

      results = runtime.execute([tc1, tc2], tools: tools, context: context)

      expect(results.length).must_equal 2
      expect(results[0][0]).must_equal tc1
      expect(results[0][1].content).must_equal "Weather in Toronto: 20 degrees"
      expect(results[1][0]).must_equal tc2
      expect(results[1][1].content).must_equal "Weather in London: 20 degrees"
    end
  end

  describe ".around_tool_execution" do
    it "wraps each call" do
      log = []
      runtime_class = Class.new(Riffer::ToolRuntime) do
        around_tool_execution do |tool_call, context:, &block|
          log << "before:#{tool_call.name}"
          result = block.call
          log << "after:#{tool_call.name}"
          result
        end
      end

      runtime = runtime_class.new
      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')

      runtime.execute([tool_call], tools: tools, context: context)

      expect(log).must_equal ["before:weather_tool", "after:weather_tool"]
    end

    it "composes multiple callbacks in order" do
      log = []
      runtime_class = Class.new(Riffer::ToolRuntime) do
        around_tool_execution do |tool_call, context:, &block|
          log << "outer:before"
          result = block.call
          log << "outer:after"
          result
        end

        around_tool_execution do |tool_call, context:, &block|
          log << "inner:before"
          result = block.call
          log << "inner:after"
          result
        end
      end

      runtime = runtime_class.new
      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')

      runtime.execute([tool_call], tools: tools, context: context)

      expect(log).must_equal ["outer:before", "inner:before", "inner:after", "outer:after"]
    end
  end
end

describe Riffer::ToolRuntime::Inline do
  it "behaves identically to base" do
    runtime = Riffer::ToolRuntime::Inline.new
    expect(runtime).must_be_kind_of Riffer::ToolRuntime
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

    runtime = Riffer::ToolRuntime::Inline.new
    tool_call = Riffer::Messages::Assistant::ToolCall.new(
      id: "1", call_id: "cid_1", name: "weather_tool", arguments: '{"city":"Toronto"}'
    )

    results = runtime.execute([tool_call], tools: [weather_tool], context: nil)

    expect(results.length).must_equal 1
    expect(results[0][1].content).must_equal "Weather in Toronto: 20 degrees"
  end
end

describe Riffer::ToolRuntime::Threaded do
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

    runtime = Riffer::ToolRuntime::Threaded.new(max_concurrency: 3)
    tool_calls = 3.times.map do |i|
      Riffer::Messages::Assistant::ToolCall.new(
        id: i.to_s, call_id: "cid_#{i}", name: "tracking_tool", arguments: "{}"
      )
    end

    results = runtime.execute(tool_calls, tools: [tracking_tool], context: nil)

    expect(results.length).must_equal 3
    expect(seen.uniq.length).must_equal 3
  end
end
