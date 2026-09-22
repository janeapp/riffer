# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::ReasoningDone do
  describe "#initialize" do
    it "sets the content" do
      event = Riffer::StreamEvents::ReasoningDone.new("Hello")

      expect(event.content).must_equal "Hello"
    end

    it "sets default role to assistant" do
      event = Riffer::StreamEvents::ReasoningDone.new("Hello")

      expect(event.role).must_equal :assistant
    end

    it "allows setting custom role" do
      event = Riffer::StreamEvents::ReasoningDone.new("Hello", role: :user)

      expect(event.role).must_equal :user
    end

    it "leaves the part nil by default" do
      event = Riffer::StreamEvents::ReasoningDone.new("Hello")

      expect(event.part).must_be_nil
    end

    it "carries the reasoning part when given" do
      part = Riffer::Messages::Assistant::ReasoningPart.new(type: :text, text: "Hello", format: "mock-v1")
      event = Riffer::StreamEvents::ReasoningDone.new("Hello", part: part)

      expect(event.part).must_equal part
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      event = Riffer::StreamEvents::ReasoningDone.new("Hello")

      expect(event.to_h).must_equal({ role: :assistant, content: "Hello" })
    end

    it "includes the part when one is present" do
      part = Riffer::Messages::Assistant::ReasoningPart.new(type: :text, text: "Hello", format: "mock-v1")
      event = Riffer::StreamEvents::ReasoningDone.new("Hello", part: part)

      expect(event.to_h).must_equal(
        { role: :assistant, content: "Hello", part: { type: :text, text: "Hello", format: "mock-v1" } },
      )
    end
  end
end
