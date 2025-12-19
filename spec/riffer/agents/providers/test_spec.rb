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

    it "initializes calls to empty array" do
      provider = described_class.new
      expect(provider.calls).to eq([])
    end
  end

  describe "#stub_response" do
    it "sets a stubbed response with content" do
      provider = described_class.new
      provider.stub_response("Hello from the machine!")
      result = provider.chat(messages: [{role: "user", content: "Hi"}], model: "test")
      expect(result[:content]).to eq("Hello from the machine!")
    end

    it "sets a stubbed response with tool_calls" do
      provider = described_class.new
      provider.stub_response("Hello", tool_calls: [{name: "test_tool"}])
      result = provider.chat(messages: [{role: "user", content: "Hi"}], model: "test")
      expect(result[:tool_calls]).to eq([{name: "test_tool"}])
    end

    it "sets a stubbed response with empty tool_calls by default" do
      provider = described_class.new
      provider.stub_response("Hello from the machine!", tool_calls: [])
      result = provider.chat(messages: [{role: "user", content: "Hi"}], model: "test")
      expect(result[:tool_calls]).to eq([])
    end
  end

  describe "#calls" do
    it "tracks each call to chat" do
      provider = described_class.new
      expect(provider.calls).to be_empty
      provider.chat(messages: [{role: "user", content: "Hi"}], model: "test")
      expect(provider.calls.count).to eq(1)
    end

    it "stores messages in call history" do
      provider = described_class.new
      messages = [{role: "user", content: "Hi"}]
      provider.chat(messages: messages, model: "test")
      expect(provider.calls.first[:messages]).to eq(messages)
    end

    it "stores model in call history" do
      provider = described_class.new
      provider.chat(messages: [], model: "gpt-4")
      expect(provider.calls.first[:model]).to eq("gpt-4")
    end

    it "stores options in call history" do
      provider = described_class.new
      provider.chat(messages: [], model: "test", temperature: 0.7)
      expect(provider.calls.first[:options]).to eq({temperature: 0.7})
    end

    it "tracks multiple calls" do
      provider = described_class.new
      provider.chat(messages: [{role: "user", content: "First"}], model: "test")
      provider.chat(messages: [{role: "user", content: "Second"}], model: "test")
      expect(provider.calls.count).to eq(2)
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

    it "prefers stubbed response over responses array" do
      provider = described_class.new(responses: [{role: "assistant", content: "From array"}])
      provider.stub_response("Stubbed response")
      result = provider.chat(messages: [], model: "test")
      expect(result[:content]).to eq("Stubbed response")
    end

    it "uses stubbed response for all calls when set" do
      provider = described_class.new
      provider.stub_response("Same response", tool_calls: [])
      first = provider.chat(messages: [], model: "test")
      second = provider.chat(messages: [], model: "test")
      expect(first[:content]).to eq("Same response")
      expect(second[:content]).to eq("Same response")
    end
  end
end
