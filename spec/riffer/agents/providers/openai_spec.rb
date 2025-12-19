# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Providers::OpenAI do
  describe "#initialize" do
    it "accepts an explicit api_key" do
      provider = described_class.new(api_key: "explicit_key")
      expect(provider.instance_variable_get(:@api_key)).to eq("explicit_key")
    end

    it "falls back to OPENAI_API_KEY environment variable" do
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("env_key")
      provider = described_class.new
      expect(provider.instance_variable_get(:@api_key)).to eq("env_key")
    end

    it "uses explicit api_key over environment variable" do
      allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("env_key")
      provider = described_class.new(api_key: "explicit_key")
      expect(provider.instance_variable_get(:@api_key)).to eq("explicit_key")
    end
  end

  describe "#chat" do
    it "returns a response hash" do
      provider = described_class.new(api_key: "test_key")
      result = provider.chat(messages: [], model: "gpt-4")
      expect(result).to be_a(Hash)
    end

    it "includes role in response" do
      provider = described_class.new(api_key: "test_key")
      result = provider.chat(messages: [], model: "gpt-4")
      expect(result[:role]).to eq("assistant")
    end

    it "includes content in response" do
      provider = described_class.new(api_key: "test_key")
      result = provider.chat(messages: [], model: "gpt-4")
      expect(result[:content]).to eq("OpenAI provider response")
    end
  end
end
