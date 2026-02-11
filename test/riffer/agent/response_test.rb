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
        guardrail_id: "test",
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
        guardrail_id: "test",
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
        guardrail_id: "test",
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
        guardrail_id: "test",
        phase: :before
      )
      response = Riffer::Agent::Response.new("", tripwire: tripwire)
      expect(response.blocked?).must_equal true
    end
  end
end
