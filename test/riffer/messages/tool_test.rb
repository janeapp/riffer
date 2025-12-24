# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::Tool do
  describe "#role" do
    it "returns tool" do
      message = Riffer::Messages::Tool.new("Result", tool_call_id: "123", name: "my_tool")
      expect(message.role).must_equal "tool"
    end
  end

  describe "#to_h" do
    it "returns hash with role, content, tool_call_id, and name" do
      message = Riffer::Messages::Tool.new("Result", tool_call_id: "123", name: "my_tool")
      expected = {role: "tool", content: "Result", tool_call_id: "123", name: "my_tool"}
      expect(message.to_h).must_equal expected
    end
  end
end
