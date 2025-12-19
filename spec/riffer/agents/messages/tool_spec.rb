# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Messages::Tool do
  describe "#role" do
    it "returns tool" do
      message = described_class.new("Result", tool_call_id: "123", name: "my_tool")
      expect(message.role).to eq("tool")
    end
  end

  describe "#to_h" do
    it "returns hash with role, content, tool_call_id, and name" do
      message = described_class.new("Result", tool_call_id: "123", name: "my_tool")
      expected = {role: "tool", content: "Result", tool_call_id: "123", name: "my_tool"}
      expect(message.to_h).to eq(expected)
    end
  end
end
