# frozen_string_literal: true

require "test_helper"

describe Riffer::Guardrails::Modification do
  let(:stub_guardrail_class) { Class.new(Riffer::Guardrail) }

  describe "#guardrail" do
    it "returns the guardrail class" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail: stub_guardrail_class,
        phase: :before,
        message_indices: [0, 1]
      )
      expect(modification.guardrail).must_equal stub_guardrail_class
    end
  end

  describe "#phase" do
    it "returns the phase" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail: stub_guardrail_class,
        phase: :after,
        message_indices: [0]
      )
      expect(modification.phase).must_equal :after
    end
  end

  describe "#message_indices" do
    it "returns the message indices" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail: stub_guardrail_class,
        phase: :before,
        message_indices: [1, 3]
      )
      expect(modification.message_indices).must_equal [1, 3]
    end
  end

  describe "#to_h" do
    it "returns a hash with guardrail as string" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail: stub_guardrail_class,
        phase: :before,
        message_indices: [0]
      )
      expect(modification.to_h[:guardrail]).must_be_kind_of String
      expect(modification.to_h[:guardrail]).wont_be_empty
    end

    it "returns a hash with phase" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail: stub_guardrail_class,
        phase: :after,
        message_indices: [0]
      )
      expect(modification.to_h[:phase]).must_equal :after
    end

    it "returns a hash with message_indices" do
      modification = Riffer::Guardrails::Modification.new(
        guardrail: stub_guardrail_class,
        phase: :before,
        message_indices: [0, 2]
      )
      expect(modification.to_h[:message_indices]).must_equal [0, 2]
    end
  end
end
