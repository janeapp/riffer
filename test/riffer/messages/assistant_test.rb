# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::Assistant do
  describe "#role" do
    it "returns assistant" do
      message = Riffer::Messages::Assistant.new("I can help")
      expect(message.role).must_equal "assistant"
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      message = Riffer::Messages::Assistant.new("I can help")
      expect(message.to_h).must_equal({role: "assistant", content: "I can help"})
    end

    it "includes tool_calls when provided" do
      message = Riffer::Messages::Assistant.new("Using tool", tool_calls: [{id: "1", name: "test"}])
      expect(message.to_h[:tool_calls]).must_equal [{id: "1", name: "test"}]
    end

    it "excludes tool_calls when empty" do
      message = Riffer::Messages::Assistant.new("No tools")
      expect(message.to_h).must_equal({role: "assistant", content: "No tools"})
    end
  end
end
