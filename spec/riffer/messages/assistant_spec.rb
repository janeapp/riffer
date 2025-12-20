# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Messages::Assistant do
  describe "#role" do
    it "returns assistant" do
      message = described_class.new("I can help")
      expect(message.role).to eq("assistant")
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      message = described_class.new("I can help")
      expect(message.to_h).to eq({role: "assistant", content: "I can help"})
    end

    it "includes tool_calls when provided" do
      message = described_class.new("Using tool", tool_calls: [{id: "1", name: "test"}])
      expect(message.to_h[:tool_calls]).to eq([{id: "1", name: "test"}])
    end

    it "excludes tool_calls when empty" do
      message = described_class.new("No tools")
      expect(message.to_h).to eq({role: "assistant", content: "No tools"})
    end
  end
end
