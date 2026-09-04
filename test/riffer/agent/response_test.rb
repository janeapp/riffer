# frozen_string_literal: true

require "test_helper"

describe Riffer::Agent::Response do
  let(:completed) { Riffer::Agent::Outcome.new(reason: :completed) }

  describe "#initialize" do
    it "stores the content" do
      response = Riffer::Agent::Response.new("Hello!", outcome: completed)

      expect(response.content).must_equal "Hello!"
    end

    it "requires an outcome" do
      expect { Riffer::Agent::Response.new("Hello!") }.must_raise ArgumentError
    end

    it "defaults tripwire to nil" do
      response = Riffer::Agent::Response.new("Hello!", outcome: completed)

      expect(response.tripwire).must_be_nil
    end

    it "stores the tripwire" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail: Riffer::Guardrail,
        phase: :before,
      )
      outcome = Riffer::Agent::Outcome.new(reason: :guardrail_blocked, detail: "blocked")
      response = Riffer::Agent::Response.new("", outcome: outcome, tripwire: tripwire)

      expect(response.tripwire).must_equal tripwire
    end
  end

  describe "#outcome" do
    it "returns the outcome" do
      response = Riffer::Agent::Response.new("Hello!", outcome: completed)

      expect(response.outcome).must_be_same_as completed
    end
  end

  describe "#modifications" do
    it "defaults to empty array" do
      response = Riffer::Agent::Response.new("Hello!", outcome: completed)

      expect(response.modifications).must_equal []
    end

    it "returns provided modifications" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail: Riffer::Guardrail,
        phase: :before,
        message_indices: [0],
      )
      response = Riffer::Agent::Response.new("Hello!", outcome: completed, modifications: [modification])

      expect(response.modifications).must_equal [modification]
    end
  end

  describe "#modified?" do
    it "returns false when no modifications" do
      response = Riffer::Agent::Response.new("Hello!", outcome: completed)

      expect(response.modified?).must_equal false
    end

    it "returns true when modifications present" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail: Riffer::Guardrail,
        phase: :before,
        message_indices: [0],
      )
      response = Riffer::Agent::Response.new("Hello!", outcome: completed, modifications: [modification])

      expect(response.modified?).must_equal true
    end
  end

  describe "#structured_output" do
    it "defaults to nil" do
      response = Riffer::Agent::Response.new("Hello!", outcome: completed)

      expect(response.structured_output).must_be_nil
    end

    it "stores the structured output" do
      response = Riffer::Agent::Response.new(
        "Hello!",
        outcome: completed,
        structured_output: { sentiment: "positive", score: 0.9 },
      )

      expect(response.structured_output).must_equal({ sentiment: "positive", score: 0.9 })
    end
  end

  describe "#messages" do
    it "defaults to empty array" do
      response = Riffer::Agent::Response.new("Hello!", outcome: completed)

      expect(response.messages).must_equal []
    end

    it "stores the messages" do
      messages = [Riffer::Messages::User.new("Hi"), Riffer::Messages::Assistant.new("Hello")]
      response = Riffer::Agent::Response.new("Hello!", outcome: completed, messages: messages)

      expect(response.messages).must_equal messages
    end
  end

  describe "#token_usage" do
    it "defaults to nil" do
      response = Riffer::Agent::Response.new("Hello!", outcome: completed)

      expect(response.token_usage).must_be_nil
    end

    it "stores the token usage" do
      usage = Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      response = Riffer::Agent::Response.new("Hello!", outcome: completed, token_usage: usage)

      expect(response.token_usage).must_equal usage
    end
  end

  describe "#steps" do
    it "defaults to zero" do
      response = Riffer::Agent::Response.new("Hello!", outcome: completed)

      expect(response.steps).must_equal 0
    end

    it "stores the step count" do
      response = Riffer::Agent::Response.new("Hello!", outcome: completed, steps: 3)

      expect(response.steps).must_equal 3
    end
  end
end
