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

    it "defaults signature and redacted_data to nil" do
      event = Riffer::StreamEvents::ReasoningDone.new("Hello")

      expect(event.signature).must_be_nil
      expect(event.redacted_data).must_be_nil
    end

    it "sets the signature" do
      event = Riffer::StreamEvents::ReasoningDone.new("Hello", signature: "sig_1")

      expect(event.signature).must_equal "sig_1"
    end

    it "sets the redacted payload" do
      event = Riffer::StreamEvents::ReasoningDone.new("", redacted_data: "encrypted")

      expect(event.redacted_data).must_equal "encrypted"
    end

    it "defaults the id to nil" do
      expect(Riffer::StreamEvents::ReasoningDone.new("Hello").id).must_be_nil
    end

    it "sets the id" do
      event = Riffer::StreamEvents::ReasoningDone.new("Hello", id: "rs_1")

      expect(event.id).must_equal "rs_1"
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      event = Riffer::StreamEvents::ReasoningDone.new("Hello")

      expect(event.to_h).must_equal({ role: :assistant, content: "Hello" })
    end

    it "includes the signature when set" do
      event = Riffer::StreamEvents::ReasoningDone.new("Hello", signature: "sig_1")

      expect(event.to_h).must_equal({ role: :assistant, content: "Hello", signature: "sig_1" })
    end

    it "includes the redacted payload when set" do
      event = Riffer::StreamEvents::ReasoningDone.new("", redacted_data: "encrypted")

      expect(event.to_h).must_equal({ role: :assistant, content: "", redacted_data: "encrypted" })
    end

    it "includes the id when set" do
      event = Riffer::StreamEvents::ReasoningDone.new("Hello", id: "rs_1")

      expect(event.to_h).must_equal({ role: :assistant, content: "Hello", id: "rs_1" })
    end
  end
end
