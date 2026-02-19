# frozen_string_literal: true

require "test_helper"

describe Riffer::Tools::Executor do
  let(:executor) { Riffer::Tools::Executor.new }

  describe "#tools_for_provider" do
    it "raises NotImplementedError" do
      expect { executor.tools_for_provider }.must_raise NotImplementedError
    end
  end

  describe "#execute" do
    it "raises NotImplementedError" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(
        id: "tc_1",
        call_id: "call_1",
        name: "some_tool",
        arguments: "{}"
      )
      expect { executor.execute(tool_call, context: nil) }.must_raise NotImplementedError
    end
  end
end
