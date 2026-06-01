# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Timing do
  def build(**overrides)
    defaults = {model: "openai/gpt-4", step: 1, duration: 1.5, ttft: nil}
    Riffer::Providers::Timing.new(**defaults.merge(overrides))
  end

  describe "#initialize" do
    it "stores the model" do
      expect(build.model).must_equal "openai/gpt-4"
    end

    it "stores the step" do
      expect(build(step: 3).step).must_equal 3
    end

    it "stores the duration" do
      expect(build(duration: 2.0).duration).must_equal 2.0
    end

    it "stores the ttft" do
      expect(build(ttft: 0.3).ttft).must_equal 0.3
    end

    it "defaults ttft to nil" do
      expect(build.ttft).must_be_nil
    end
  end

  describe "#kind" do
    it "is :llm" do
      expect(build.kind).must_equal :llm
    end
  end

  describe "#ttft_ms" do
    it "converts ttft seconds to milliseconds" do
      expect(build(ttft: 0.3).ttft_ms).must_equal 300.0
    end

    it "is nil when ttft is nil" do
      expect(build(ttft: nil).ttft_ms).must_be_nil
    end
  end

  describe "#to_h" do
    it "includes the kind, model, step, duration, and ttft" do
      hash = build(ttft: 0.3).to_h
      expect(hash[:kind]).must_equal :llm
      expect(hash[:model]).must_equal "openai/gpt-4"
      expect(hash[:step]).must_equal 1
      expect(hash[:duration]).must_equal 1.5
      expect(hash[:ttft]).must_equal 0.3
    end
  end
end
