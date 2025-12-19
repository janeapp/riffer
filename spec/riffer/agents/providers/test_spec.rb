# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Providers::Test do
  let(:provider) { described_class.new }

  describe "#initialize" do
    it "initializes calls to empty array" do
      expect(provider.calls).to eq([])
    end
  end

  describe "#stub_response" do
    it "sets a stubbed response with content" do
      provider.stub_response("Hello from the machine!")
      result = provider.generate_text(prompt: "Hi")
      expect(result[:content]).to eq("Hello from the machine!")
    end
  end

  describe "#generate_text" do
    it "returns default response when no stubbed response" do
      result = provider.generate_text(prompt: "Hello")
      expect(result).to eq({role: "assistant", content: "Test response"})
    end

    it "stores normalized messages in calls" do
      provider.generate_text(prompt: "Hello")
      expect(provider.calls.last[:messages]).to eq([{role: "user", content: "Hello"}])
    end

    it "stores system and user messages in calls when both provided" do
      provider.generate_text(prompt: "Hello", system: "You are helpful")
      expect(provider.calls.last[:messages]).to eq([
        {role: "system", content: "You are helpful"},
        {role: "user", content: "Hello"}
      ])
    end
  end

  describe "#stream_text" do
    it "returns an enumerator" do
      result = provider.stream_text(prompt: "Hello")
      expect(result).to be_a(Enumerator)
    end
  end
end
