# frozen_string_literal: true

require "test_helper"

describe Riffer::Guardrails::Timing do
  def build(**overrides)
    defaults = {guardrail: Riffer::Guardrail, phase: :before, duration: 0.5, result_type: :pass}
    Riffer::Guardrails::Timing.new(**defaults.merge(overrides))
  end

  describe "#initialize" do
    it "stores the guardrail" do
      expect(build.guardrail).must_equal Riffer::Guardrail
    end

    it "stores the phase" do
      expect(build(phase: :after).phase).must_equal :after
    end

    it "stores the duration" do
      expect(build(duration: 1.25).duration).must_equal 1.25
    end

    it "stores the result type" do
      expect(build(result_type: :block).result_type).must_equal :block
    end

    it "defaults result_type to nil" do
      timing = Riffer::Guardrails::Timing.new(guardrail: Riffer::Guardrail, phase: :before, duration: 0.1)
      expect(timing.result_type).must_be_nil
    end
  end

  describe "#kind" do
    it "is :guardrail" do
      expect(build.kind).must_equal :guardrail
    end

    it "is a Riffer::Timing" do
      expect(build).must_be_kind_of Riffer::Timing
    end
  end

  describe "#duration_ms" do
    it "converts seconds to milliseconds" do
      expect(build(duration: 0.5).duration_ms).must_equal 500.0
    end
  end

  describe "#to_h" do
    it "includes the kind" do
      expect(build.to_h[:kind]).must_equal :guardrail
    end

    it "includes the guardrail name" do
      expect(build.to_h[:guardrail]).must_equal "Riffer::Guardrail"
    end

    it "includes the phase" do
      expect(build(phase: :after).to_h[:phase]).must_equal :after
    end

    it "includes the duration" do
      expect(build(duration: 0.75).to_h[:duration]).must_equal 0.75
    end

    it "includes the result type" do
      expect(build(result_type: :transform).to_h[:result_type]).must_equal :transform
    end
  end
end
