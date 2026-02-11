# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::GuardrailTripwire do
  let(:guardrails_tripwire) do
    Riffer::Guardrails::Tripwire.new(
      reason: "PII detected",
      guardrail_id: "pii_redactor",
      phase: :before,
      metadata: {types: [:email]}
    )
  end

  describe "#initialize" do
    it "stores the tripwire" do
      event = Riffer::StreamEvents::GuardrailTripwire.new(guardrails_tripwire)
      expect(event.tripwire).must_equal guardrails_tripwire
    end

    it "defaults role to assistant" do
      event = Riffer::StreamEvents::GuardrailTripwire.new(guardrails_tripwire)
      expect(event.role).must_equal :assistant
    end

    it "allows custom role" do
      event = Riffer::StreamEvents::GuardrailTripwire.new(guardrails_tripwire, role: :system)
      expect(event.role).must_equal :system
    end
  end

  describe "#reason" do
    it "returns the tripwire reason" do
      event = Riffer::StreamEvents::GuardrailTripwire.new(guardrails_tripwire)
      expect(event.reason).must_equal "PII detected"
    end
  end

  describe "#phase" do
    it "returns the tripwire phase" do
      event = Riffer::StreamEvents::GuardrailTripwire.new(guardrails_tripwire)
      expect(event.phase).must_equal :before
    end
  end

  describe "#guardrail_id" do
    it "returns the guardrail identifier" do
      event = Riffer::StreamEvents::GuardrailTripwire.new(guardrails_tripwire)
      expect(event.guardrail_id).must_equal "pii_redactor"
    end
  end

  describe "#to_h" do
    it "returns hash with role" do
      event = Riffer::StreamEvents::GuardrailTripwire.new(guardrails_tripwire)
      expect(event.to_h[:role]).must_equal :assistant
    end

    it "returns hash with tripwire details" do
      event = Riffer::StreamEvents::GuardrailTripwire.new(guardrails_tripwire)
      expect(event.to_h[:tripwire][:reason]).must_equal "PII detected"
    end

    it "includes guardrail_id in tripwire" do
      event = Riffer::StreamEvents::GuardrailTripwire.new(guardrails_tripwire)
      expect(event.to_h[:tripwire][:guardrail_id]).must_equal "pii_redactor"
    end

    it "includes phase in tripwire" do
      event = Riffer::StreamEvents::GuardrailTripwire.new(guardrails_tripwire)
      expect(event.to_h[:tripwire][:phase]).must_equal :before
    end

    it "includes metadata in tripwire" do
      event = Riffer::StreamEvents::GuardrailTripwire.new(guardrails_tripwire)
      expect(event.to_h[:tripwire][:metadata]).must_equal({types: [:email]})
    end
  end
end
