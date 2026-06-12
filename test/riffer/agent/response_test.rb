# frozen_string_literal: true

require "test_helper"

describe Riffer::Agent::Response do
  describe "#initialize" do
    it "stores the content" do
      response = Riffer::Agent::Response.new("Hello!")
      expect(response.content).must_equal "Hello!"
    end

    it "defaults tripwire to nil" do
      response = Riffer::Agent::Response.new("Hello!")
      expect(response.tripwire).must_be_nil
    end

    it "stores the tripwire" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail: Riffer::Guardrail,
        phase: :before
      )
      response = Riffer::Agent::Response.new("", tripwire: tripwire)
      expect(response.tripwire).must_equal tripwire
    end
  end

  describe "#modifications" do
    it "defaults to empty array" do
      response = Riffer::Agent::Response.new("Hello!")
      expect(response.modifications).must_equal []
    end

    it "returns provided modifications" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail: Riffer::Guardrail,
        phase: :before,
        message_indices: [0]
      )
      response = Riffer::Agent::Response.new("Hello!", modifications: [modification])
      expect(response.modifications).must_equal [modification]
    end
  end

  describe "#modified?" do
    it "returns false when no modifications" do
      response = Riffer::Agent::Response.new("Hello!")
      expect(response.modified?).must_equal false
    end

    it "returns true when modifications present" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail: Riffer::Guardrail,
        phase: :before,
        message_indices: [0]
      )
      response = Riffer::Agent::Response.new("Hello!", modifications: [modification])
      expect(response.modified?).must_equal true
    end
  end

  describe "#blocked?" do
    it "returns false when no tripwire" do
      response = Riffer::Agent::Response.new("Hello!")
      expect(response.blocked?).must_equal false
    end

    it "returns true when tripwire present" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail: Riffer::Guardrail,
        phase: :before
      )
      response = Riffer::Agent::Response.new("", tripwire: tripwire)
      expect(response.blocked?).must_equal true
    end
  end

  describe "#structured_output" do
    it "defaults to nil" do
      response = Riffer::Agent::Response.new("Hello!")
      expect(response.structured_output).must_be_nil
    end

    it "stores the structured output" do
      response = Riffer::Agent::Response.new("Hello!", structured_output: {sentiment: "positive", score: 0.9})
      expect(response.structured_output).must_equal({sentiment: "positive", score: 0.9})
    end
  end

  describe "#messages" do
    it "defaults to empty array" do
      response = Riffer::Agent::Response.new("Hello!")
      expect(response.messages).must_equal []
    end

    it "stores the messages" do
      messages = [Riffer::Messages::User.new("Hi"), Riffer::Messages::Assistant.new("Hello")]
      response = Riffer::Agent::Response.new("Hello!", messages: messages)
      expect(response.messages).must_equal messages
    end
  end

  describe "#token_usage" do
    it "defaults to nil" do
      response = Riffer::Agent::Response.new("Hello!")
      expect(response.token_usage).must_be_nil
    end

    it "stores the token usage" do
      usage = Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      response = Riffer::Agent::Response.new("Hello!", token_usage: usage)
      expect(response.token_usage).must_equal usage
    end
  end

  describe "#interrupted?" do
    it "returns false by default" do
      response = Riffer::Agent::Response.new("Hello!")
      expect(response.interrupted?).must_equal false
    end

    it "returns true when interrupted" do
      response = Riffer::Agent::Response.new("Hello!", interrupted: true)
      expect(response.interrupted?).must_equal true
    end
  end
end
