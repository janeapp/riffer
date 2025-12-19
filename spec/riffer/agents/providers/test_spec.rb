# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Providers::Test do
  describe "#initialize" do
    it "accepts custom responses" do
      responses = [{role: "assistant", content: "Custom response"}]
      provider = described_class.new(responses: responses)
      expect(provider.instance_variable_get(:@responses)).to eq(responses)
    end

    it "initializes with empty responses by default" do
      provider = described_class.new
      expect(provider.instance_variable_get(:@responses)).to eq([])
    end

    it "initializes current_index to zero" do
      provider = described_class.new
      expect(provider.instance_variable_get(:@current_index)).to eq(0)
    end
  end

  describe "#chat" do
    it "returns default response when no custom responses provided" do
      provider = described_class.new
      result = provider.chat(messages: [], model: "test")
      expect(result).to eq({role: "assistant", content: "Test response"})
    end

    it "returns first custom response" do
      responses = [{role: "assistant", content: "First response"}]
      provider = described_class.new(responses: responses)
      result = provider.chat(messages: [], model: "test")
      expect(result).to eq({role: "assistant", content: "First response"})
    end

    it "cycles through custom responses" do
      responses = [
        {role: "assistant", content: "First"},
        {role: "assistant", content: "Second"}
      ]
      provider = described_class.new(responses: responses)
      provider.chat(messages: [], model: "test")
      result = provider.chat(messages: [], model: "test")
      expect(result).to eq({role: "assistant", content: "Second"})
    end

    it "starts with current_index at zero" do
      provider = described_class.new(responses: [{}, {}])
      expect(provider.instance_variable_get(:@current_index)).to eq(0)
    end

    it "increments current_index after calling chat" do
      provider = described_class.new(responses: [{}, {}])
      provider.chat(messages: [], model: "test")
      expect(provider.instance_variable_get(:@current_index)).to eq(1)
    end

    it "returns default response when index exceeds responses length" do
      responses = [{role: "assistant", content: "Only one"}]
      provider = described_class.new(responses: responses)
      provider.chat(messages: [], model: "test")
      result = provider.chat(messages: [], model: "test")
      expect(result).to eq({role: "assistant", content: "Test response"})
    end
  end
end
