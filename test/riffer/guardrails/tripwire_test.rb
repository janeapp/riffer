# frozen_string_literal: true

require "test_helper"

describe Riffer::Guardrails::Tripwire do
  describe "#initialize" do
    it "creates a tripwire with required attributes" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "PII detected",
        guardrail_id: "pii_redactor",
        phase: :before
      )
      expect(tripwire.reason).must_equal "PII detected"
    end

    it "stores the guardrail_id" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail_id: "my_guardrail",
        phase: :before
      )
      expect(tripwire.guardrail_id).must_equal "my_guardrail"
    end

    it "stores the phase" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail_id: "guardrail",
        phase: :after
      )
      expect(tripwire.phase).must_equal :after
    end

    it "accepts before phase" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail_id: "guardrail",
        phase: :before
      )
      expect(tripwire.phase).must_equal :before
    end

    it "accepts after phase" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail_id: "guardrail",
        phase: :after
      )
      expect(tripwire.phase).must_equal :after
    end

    it "raises error for invalid phase" do
      error = expect do
        Riffer::Guardrails::Tripwire.new(
          reason: "blocked",
          guardrail_id: "guardrail",
          phase: :invalid
        )
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Invalid phase/)
    end

    it "stores metadata" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail_id: "guardrail",
        phase: :before,
        metadata: {detected: [:email]}
      )
      expect(tripwire.metadata).must_equal({detected: [:email]})
    end

    it "allows nil metadata" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail_id: "guardrail",
        phase: :before
      )
      expect(tripwire.metadata).must_be_nil
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "PII detected",
        guardrail_id: "pii_redactor",
        phase: :before,
        metadata: {types: [:email]}
      )
      hash = tripwire.to_h
      expect(hash[:reason]).must_equal "PII detected"
    end

    it "includes guardrail_id" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail_id: "my_guardrail",
        phase: :after
      )
      expect(tripwire.to_h[:guardrail_id]).must_equal "my_guardrail"
    end

    it "includes phase" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail_id: "guardrail",
        phase: :before
      )
      expect(tripwire.to_h[:phase]).must_equal :before
    end

    it "includes metadata" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail_id: "guardrail",
        phase: :before,
        metadata: {key: "value"}
      )
      expect(tripwire.to_h[:metadata]).must_equal({key: "value"})
    end
  end
end
