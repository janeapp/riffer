# frozen_string_literal: true

require "test_helper"

describe Riffer::Guardrails::Tripwire do
  let(:stub_guardrail_class) { Class.new(Riffer::Guardrail) }

  describe "#initialize" do
    it "creates a tripwire with required attributes" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "PII detected",
        guardrail: stub_guardrail_class,
        phase: :before
      )
      expect(tripwire.reason).must_equal "PII detected"
    end

    it "stores the guardrail" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail: stub_guardrail_class,
        phase: :before
      )
      expect(tripwire.guardrail).must_equal stub_guardrail_class
    end

    it "stores the phase" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail: stub_guardrail_class,
        phase: :after
      )
      expect(tripwire.phase).must_equal :after
    end

    it "accepts before phase" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail: stub_guardrail_class,
        phase: :before
      )
      expect(tripwire.phase).must_equal :before
    end

    it "accepts after phase" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail: stub_guardrail_class,
        phase: :after
      )
      expect(tripwire.phase).must_equal :after
    end

    it "raises error for invalid phase" do
      error = expect do
        Riffer::Guardrails::Tripwire.new(
          reason: "blocked",
          guardrail: stub_guardrail_class,
          phase: :invalid
        )
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Invalid phase/)
    end

    it "stores metadata" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail: stub_guardrail_class,
        phase: :before,
        metadata: {detected: [:email]}
      )
      expect(tripwire.metadata).must_equal({detected: [:email]})
    end

    it "allows nil metadata" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail: stub_guardrail_class,
        phase: :before
      )
      expect(tripwire.metadata).must_be_nil
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "PII detected",
        guardrail: stub_guardrail_class,
        phase: :before,
        metadata: {types: [:email]}
      )
      hash = tripwire.to_h
      expect(hash[:reason]).must_equal "PII detected"
    end

    it "includes guardrail as string" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail: stub_guardrail_class,
        phase: :after
      )
      expect(tripwire.to_h[:guardrail]).must_be_kind_of String
      expect(tripwire.to_h[:guardrail]).wont_be_empty
    end

    it "includes phase" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail: stub_guardrail_class,
        phase: :before
      )
      expect(tripwire.to_h[:phase]).must_equal :before
    end

    it "includes metadata" do
      tripwire = Riffer::Guardrails::Tripwire.new(
        reason: "blocked",
        guardrail: stub_guardrail_class,
        phase: :before,
        metadata: {key: "value"}
      )
      expect(tripwire.to_h[:metadata]).must_equal({key: "value"})
    end
  end
end
