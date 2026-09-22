# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::ReasoningDone do
  let(:part) { Riffer::Messages::Assistant::ReasoningPart.new(type: :text, text: "Hello", format: "mock-v1") }

  describe "#initialize" do
    it "carries the reasoning part" do
      event = Riffer::StreamEvents::ReasoningDone.new(part)

      expect(event.part).must_equal part
    end

    it "sets default role to assistant" do
      event = Riffer::StreamEvents::ReasoningDone.new(part)

      expect(event.role).must_equal :assistant
    end

    it "allows setting custom role" do
      event = Riffer::StreamEvents::ReasoningDone.new(part, role: :user)

      expect(event.role).must_equal :user
    end
  end

  describe "#to_h" do
    it "returns hash with role and the part" do
      event = Riffer::StreamEvents::ReasoningDone.new(part)

      expect(event.to_h).must_equal(
        { role: :assistant, part: { type: :text, text: "Hello", format: "mock-v1" } },
      )
    end
  end
end
