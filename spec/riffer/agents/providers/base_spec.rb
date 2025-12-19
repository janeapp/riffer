# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Providers::Base do
  let(:provider) { described_class.new }

  describe "#generate_text" do
    it "raises NotImplementedError when perform_generate_text not implemented" do
      expect {
        provider.generate_text(prompt: "Hello")
      }.to raise_error(NotImplementedError, "Subclasses must implement #perform_generate_text")
    end

    it "raises InvalidInputError when no prompt or messages provided" do
      expect {
        provider.generate_text
      }.to raise_error(Riffer::Agents::InvalidInputError, "prompt is required when messages is not provided")
    end

    it "raises InvalidInputError when both prompt and messages provided" do
      expect {
        provider.generate_text(prompt: "Hello", messages: [{role: "user", content: "Hi"}])
      }.to raise_error(Riffer::Agents::InvalidInputError, "cannot provide both prompt and messages")
    end

    it "raises InvalidInputError when messages has no user message" do
      expect {
        provider.generate_text(messages: [{role: "system", content: "You are helpful"}])
      }.to raise_error(Riffer::Agents::InvalidInputError, "messages must include at least one user message")
    end
  end

  describe "#stream_text" do
    it "raises NotImplementedError when perform_stream_text not implemented" do
      expect {
        provider.stream_text(prompt: "Hello")
      }.to raise_error(NotImplementedError, "Subclasses must implement #perform_stream_text")
    end
  end
end
