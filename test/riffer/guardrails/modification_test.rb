# frozen_string_literal: true

require "test_helper"

describe Riffer::Guardrails::Modification do
  describe "#guardrail_id" do
    it "returns the guardrail identifier" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail_id: "pii_redactor",
        phase: :before,
        message_indices: [0, 1]
      )
      expect(modification.guardrail_id).must_equal "pii_redactor"
    end
  end

  describe "#phase" do
    it "returns the phase" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail_id: "normalizer",
        phase: :after,
        message_indices: [0]
      )
      expect(modification.phase).must_equal :after
    end
  end

  describe "#message_indices" do
    it "returns the message indices" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail_id: "normalizer",
        phase: :before,
        message_indices: [1, 3]
      )
      expect(modification.message_indices).must_equal [1, 3]
    end
  end

  describe "#to_h" do
    it "returns a hash with guardrail_id" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail_id: "pii_redactor",
        phase: :before,
        message_indices: [0]
      )
      expect(modification.to_h[:guardrail_id]).must_equal "pii_redactor"
    end

    it "returns a hash with phase" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail_id: "pii_redactor",
        phase: :after,
        message_indices: [0]
      )
      expect(modification.to_h[:phase]).must_equal :after
    end

    it "returns a hash with message_indices" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail_id: "pii_redactor",
        phase: :before,
        message_indices: [0, 2]
      )
      expect(modification.to_h[:message_indices]).must_equal [0, 2]
    end
  end
end
