# frozen_string_literal: true

require "test_helper"

describe Riffer::Tools::RpcExecutor do
  let(:proxy) do
    Riffer::Tools::ToolProxy.new(name: "weather", description: "Gets weather")
  end

  let(:callback) do
    ->(tool_call, context:) { Riffer::Tools::Response.text("callback: #{tool_call.name}") }
  end

  let(:executor) { Riffer::Tools::RpcExecutor.new([proxy], callback: callback) }

  def make_tool_call(name:, arguments: "{}")
    Riffer::Messages::Assistant::ToolCall.new(
      id: "tc_1",
      call_id: "call_1",
      name: name,
      arguments: arguments
    )
  end

  describe "#tools_for_provider" do
    it "returns the tool proxy objects" do
      expect(executor.tools_for_provider).must_equal [proxy]
    end
  end

  describe "#execute" do
    it "delegates to the callback" do
      tool_call = make_tool_call(name: "weather")
      result = executor.execute(tool_call, context: nil)
      expect(result.success?).must_equal true
      expect(result.content).must_equal "callback: weather"
    end

    it "returns unknown_tool error without calling callback" do
      called = false
      tracking_callback = lambda { |tc, context:|
        called = true
        Riffer::Tools::Response.text("ok")
      }
      exec = Riffer::Tools::RpcExecutor.new([proxy], callback: tracking_callback)

      tool_call = make_tool_call(name: "nonexistent")
      result = exec.execute(tool_call, context: nil)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :unknown_tool
      expect(called).must_equal false
    end

    it "wraps callback exceptions in execution_error" do
      failing_callback = ->(_tc, context:) { raise "callback failed" }
      exec = Riffer::Tools::RpcExecutor.new([proxy], callback: failing_callback)

      tool_call = make_tool_call(name: "weather")
      result = exec.execute(tool_call, context: nil)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :execution_error
      expect(result.content).must_include "callback failed"
    end

    it "passes context to the callback" do
      context_callback = ->(_tc, context:) { Riffer::Tools::Response.text(context[:key]) }
      exec = Riffer::Tools::RpcExecutor.new([proxy], callback: context_callback)

      tool_call = make_tool_call(name: "weather")
      result = exec.execute(tool_call, context: {key: "value"})

      expect(result.success?).must_equal true
      expect(result.content).must_equal "value"
    end
  end
end
