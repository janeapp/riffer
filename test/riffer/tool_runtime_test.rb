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

  def execute_single(runtime, tool_call, tools:, context:)
    results = runtime.execute([tool_call], tools: tools, context: context)
    results[0][1]
  end

  describe "#execute" do
    it "dispatches to correct tool and returns response" do
      runtime = Riffer::ToolRuntime.new
      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')

      result = execute_single(runtime, tool_call, tools: tools, context: context)

      expect(result).must_be_instance_of Riffer::Tools::Response
      expect(result.content).must_equal "Weather in Toronto: 20 degrees"
      expect(result.success?).must_equal true
    end

    it "returns error response for unknown tool" do
      runtime = Riffer::ToolRuntime.new
      tool_call = make_tool_call(name: "nonexistent", arguments: "{}")

      result = execute_single(runtime, tool_call, tools: tools, context: context)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :unknown_tool
      expect(result.content).must_match(/Unknown tool 'nonexistent'/)
    end

    it "returns error response for validation failure" do
      runtime = Riffer::ToolRuntime.new
      tool_call = make_tool_call(name: "weather_tool", arguments: "{}")

      result = execute_single(runtime, tool_call, tools: tools, context: context)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :validation_error
    end

    it "returns error response for timeout" do
      runtime = Riffer::ToolRuntime.new
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

      runtime = Riffer::ToolRuntime.new
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

      runtime = Riffer::ToolRuntime.new
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

      runtime = Riffer::ToolRuntime.new
      tool_call = make_tool_call(name: "buggy_tool", arguments: "{}")

      expect {
        runtime.execute([tool_call], tools: [buggy_tool], context: context)
      }.must_raise NoMethodError
    end

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

  describe "#around_tool_call" do
    it "yields by default" do
      runtime = Riffer::ToolRuntime.new
      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')

      results = runtime.execute([tool_call], tools: tools, context: context)

      expect(results[0][1].content).must_equal "Weather in Toronto: 20 degrees"
    end

    it "can be overridden directly" do
      log = []
      runtime_class = Class.new(Riffer::ToolRuntime) do
        define_method(:around_tool_call) do |tool_call, context:, &block|
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
      parent = Class.new(Riffer::ToolRuntime) do
        around_tool_call do |tool_call, context:, &block|
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
      parent = Class.new(Riffer::ToolRuntime) do
        around_tool_call do |_, context:, &block|
          log << "parent"
          block.call
        end
      end

      child = Class.new(parent) do
        around_tool_call do |_, context:, &block|
          log << "child"
          block.call
        end
      end

      tool_call = make_tool_call(name: "weather_tool", arguments: '{"city":"Toronto"}')
      child.new.execute([tool_call], tools: tools, context: context)

      expect(log).must_equal ["child"]
    end
  end

  describe ".around_tool_call" do
    it "defines around_tool_call with a block" do
      log = []
      runtime_class = Class.new(Riffer::ToolRuntime) do
        around_tool_call do |tool_call, context:, &block|
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

    it "defines around_tool_call with a symbol" do
      log = []
      runtime_class = Class.new(Riffer::ToolRuntime) do
        around_tool_call :instrument

        define_method(:instrument) do |tool_call, context:, &block|
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

    it "raises when given both a symbol and a block" do
      expect {
        Class.new(Riffer::ToolRuntime) do
          around_tool_call(:instrument) do |_, context:, &block|
            block.call
          end
        end
      }.must_raise Riffer::ArgumentError
    end

    it "raises when given neither a symbol nor a block" do
      expect {
        Class.new(Riffer::ToolRuntime) do
          around_tool_call
        end
      }.must_raise Riffer::ArgumentError
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
