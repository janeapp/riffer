# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Providers::OpenAI do
  describe "#generate_text" do
    it "returns a response hash with prompt" do
      result = described_class.new.generate_text(prompt: "Hello")
      expect(result).to be_a(Hash)
    end

    it "returns a response hash with messages" do
      result = described_class.new.generate_text(messages: [{role: "user", content: "Hello"}])
      expect(result).to be_a(Hash)
    end
  end

  describe "#stream_text" do
    it "returns an enumerator with prompt" do
      result = described_class.new.stream_text(prompt: "Hello")
      expect(result).to be_a(Enumerator)
    end

    it "returns an enumerator with messages" do
      result = described_class.new.stream_text(messages: [{role: "user", content: "Hello"}])
      expect(result).to be_a(Enumerator)
    end
  end
end
