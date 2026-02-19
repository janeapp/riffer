# frozen_string_literal: true

require "test_helper"

describe Riffer::Tools::LocalExecutor do
  let(:weather_tool_class) do
    Class.new(Riffer::Tool) do
      identifier "weather"
      description "Gets the weather"

      params do
        required :city, String
      end

      def call(context:, city:)
        text("Weather in #{city}: 20 degrees")
      end
    end
  end

  let(:context_tool_class) do
    Class.new(Riffer::Tool) do
      identifier "context_reader"
      description "Reads context"

      def call(context:, **)
        text(context[:user_id].to_s)
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

  let(:validation_tool_class) do
    Class.new(Riffer::Tool) do
      identifier "validation_tool"
      description "Tool with strict params"

      params do
        required :name, String
      end

      def call(context:, name:)
        text(name)
      end
    end
  end

  let(:failing_tool_class) do
    Class.new(Riffer::Tool) do
      identifier "failing_tool"
      description "Always fails"

      def call(context:, **)
        raise "Something went wrong"
      end
    end
  end

  let(:executor) { Riffer::Tools::LocalExecutor.new([weather_tool_class]) }

  def make_tool_call(name:, arguments: "{}")
    Riffer::Messages::Assistant::ToolCall.new(
      id: "tc_1",
      call_id: "call_1",
      name: name,
      arguments: arguments
    )
  end

  describe "#tools_for_provider" do
    it "returns the tool classes" do
      expect(executor.tools_for_provider).must_equal [weather_tool_class]
    end
  end

  describe "#execute" do
    it "executes a tool call successfully" do
      tool_call = make_tool_call(name: "weather", arguments: '{"city":"Paris"}')
      result = executor.execute(tool_call, context: nil)
      expect(result.success?).must_equal true
      expect(result.content).must_equal "Weather in Paris: 20 degrees"
    end

    it "returns unknown_tool error for unregistered tool" do
      tool_call = make_tool_call(name: "nonexistent")
      result = executor.execute(tool_call, context: nil)
      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :unknown_tool
    end

    it "returns validation_error for invalid arguments" do
      exec = Riffer::Tools::LocalExecutor.new([validation_tool_class])
      tool_call = make_tool_call(name: "validation_tool", arguments: '{"name":123}')
      result = exec.execute(tool_call, context: nil)
      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :validation_error
    end

    it "returns timeout_error when tool exceeds timeout" do
      exec = Riffer::Tools::LocalExecutor.new([slow_tool_class])
      tool_call = make_tool_call(name: "slow_tool")
      result = exec.execute(tool_call, context: nil)
      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :timeout_error
    end

    it "returns execution_error when tool raises" do
      exec = Riffer::Tools::LocalExecutor.new([failing_tool_class])
      tool_call = make_tool_call(name: "failing_tool")
      result = exec.execute(tool_call, context: nil)
      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :execution_error
      expect(result.content).must_include "Something went wrong"
    end

    it "passes context through to the tool" do
      exec = Riffer::Tools::LocalExecutor.new([context_tool_class])
      tool_call = make_tool_call(name: "context_reader")
      result = exec.execute(tool_call, context: {user_id: 42})
      expect(result.success?).must_equal true
      expect(result.content).must_equal "42"
    end
  end
end
