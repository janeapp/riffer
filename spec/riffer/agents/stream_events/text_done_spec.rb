# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::StreamEvents::TextDone do
  describe "#initialize" do
    it "sets the content" do
      event = described_class.new("Hello")
      expect(event.content).to eq("Hello")
    end

    it "sets default role to assistant" do
      event = described_class.new("Hello")
      expect(event.role).to eq("assistant")
    end

    it "allows setting custom role" do
      event = described_class.new("Hello", role: "user")
      expect(event.role).to eq("user")
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      event = described_class.new("Hello")
      expect(event.to_h).to eq({role: "assistant", content: "Hello"})
    end
  end
end
