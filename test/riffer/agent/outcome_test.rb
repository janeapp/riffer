# frozen_string_literal: true

require "test_helper"

describe Riffer::Agent::Outcome do
  describe "#initialize" do
    it "exposes the reason" do
      outcome = Riffer::Agent::Outcome.new(reason: :interrupted, detail: "needs approval")

      expect(outcome.reason).must_equal :interrupted
    end

    it "exposes the detail" do
      outcome = Riffer::Agent::Outcome.new(reason: :interrupted, detail: "needs approval")

      expect(outcome.detail).must_equal "needs approval"
    end

    it "defaults detail to nil" do
      outcome = Riffer::Agent::Outcome.new(reason: :completed)

      expect(outcome.detail).must_be_nil
    end

    it "accepts every value in the vocabulary" do
      reasons = Riffer::Agent::Outcome::VALUES.map { |v| Riffer::Agent::Outcome.new(reason: v).reason }

      expect(reasons).must_equal %i[
        completed guardrail_blocked interrupted max_steps invalid_structured_output
        length content_filter context_window malformed_output error other
      ]
    end

    it "raises on a reason outside the vocabulary" do
      error = expect { Riffer::Agent::Outcome.new(reason: :bogus) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_include ":bogus"
    end
  end

  describe "#success?" do
    it "returns true when completed" do
      expect(Riffer::Agent::Outcome.new(reason: :completed).success?).must_equal true
    end

    it "returns false for every other reason" do
      others = (Riffer::Agent::Outcome::VALUES - [:completed]).map { |v| Riffer::Agent::Outcome.new(reason: v).success? }

      expect(others.uniq).must_equal [false]
    end
  end
end
