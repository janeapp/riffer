# frozen_string_literal: true

require "test_helper"

describe Riffer::Timing do
  describe "#kind" do
    it "raises NotImplementedError on the abstract base" do
      timing = Riffer::Timing.new(duration: 0.1)
      expect { timing.kind }.must_raise NotImplementedError
    end
  end

  describe "#duration_ms" do
    it "converts seconds to milliseconds" do
      expect(Riffer::Timing.new(duration: 0.5).duration_ms).must_equal 500.0
    end
  end

  describe "subclasses" do
    it "are all Riffer::Timing" do
      expect(Riffer::Guardrails::Timing.ancestors).must_include Riffer::Timing
      expect(Riffer::Tools::Timing.ancestors).must_include Riffer::Timing
      expect(Riffer::Providers::Timing.ancestors).must_include Riffer::Timing
    end
  end
end
