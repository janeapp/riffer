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
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      event = Riffer::StreamEvents::ReasoningDone.new("Hello")
      expect(event.to_h).must_equal({role: :assistant, content: "Hello"})
    end
  end
end
