# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Test do
  let(:provider) { Riffer::Providers::Test.new }

  describe "#initialize" do
    it "initializes calls to empty array" do
      expect(provider.calls).must_equal []
    end
  end

  describe "#stub_response" do
    it "sets a stubbed response with content" do
      provider.stub_response("Hello from the machine!")
      result = provider.generate_text(prompt: "Hi")
      expect(result).must_be_instance_of Riffer::Messages::Assistant
    end

    it "sets the content of the stubbed response" do
      provider.stub_response("Hello from the machine!")
      result = provider.generate_text(prompt: "Hi")
      expect(result.content).must_equal "Hello from the machine!"
    end
  end

  describe "#generate_text" do
    it "returns an Assistant message when no stubbed response" do
      result = provider.generate_text(prompt: "Hello")
      expect(result).must_be_instance_of Riffer::Messages::Assistant
    end

    it "returns default content when no stubbed response" do
      result = provider.generate_text(prompt: "Hello")
      expect(result.content).must_equal "Test response"
    end

    it "stores normalized messages in calls" do
      provider.generate_text(prompt: "Hello")
      expect(provider.calls.last[:messages]).must_equal [{role: "user", content: "Hello"}]
    end

    it "stores system and user messages in calls when both provided" do
      provider.generate_text(prompt: "Hello", system: "You are helpful")
      expect(provider.calls.last[:messages]).must_equal [
        {role: "system", content: "You are helpful"},
        {role: "user", content: "Hello"}
      ]
    end

    it "stores model parameter in calls" do
      provider.generate_text(prompt: "Hello", model: "test-model")
      expect(provider.calls.last[:model]).must_equal "test-model"
    end

    it "stores reasoning parameter in calls" do
      provider.generate_text(prompt: "Hello", reasoning: "high")
      expect(provider.calls.last[:reasoning]).must_equal "high"
    end
  end

  describe "#stream_text" do
    it "returns an enumerator" do
      result = provider.stream_text(prompt: "Hello")
      expect(result).must_be_instance_of Enumerator
    end

    it "emits TextDelta events" do
      events = provider.stream_text(prompt: "Question").to_a
      text_deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
      expect(text_deltas.size).must_be :>, 0
    end

    it "emits TextDone event" do
      events = provider.stream_text(prompt: "Question").to_a
      text_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
      expect(text_done).wont_be_nil
    end

    it "stores options in calls" do
      provider.stream_text(prompt: "Hello", reasoning: "high").to_a
      expect(provider.calls.last[:reasoning]).must_equal "high"
    end
  end
end
