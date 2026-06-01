# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::Timing do
  let(:guardrail_timing) do
    Riffer::Guardrails::Timing.new(
      guardrail: Riffer::Guardrail,
      phase: :before,
      duration: 0.25,
      result_type: :pass
    )
  end

  let(:tool_timing) do
    Riffer::Tools::Timing.new(tool_name: "get_weather", call_id: "call_1", duration: 0.4)
  end

  describe "#timing" do
    it "returns the wrapped timing record" do
      event = Riffer::StreamEvents::Timing.new(guardrail_timing)
      expect(event.timing).must_equal guardrail_timing
    end
  end

  describe "#kind" do
    it "delegates to the timing for a guardrail" do
      event = Riffer::StreamEvents::Timing.new(guardrail_timing)
      expect(event.kind).must_equal :guardrail
    end

    it "delegates to the timing for a tool" do
      event = Riffer::StreamEvents::Timing.new(tool_timing)
      expect(event.kind).must_equal :tool
    end
  end

  describe "#duration" do
    it "delegates to the timing" do
      event = Riffer::StreamEvents::Timing.new(guardrail_timing)
      expect(event.duration).must_equal 0.25
    end
  end

  describe "#role" do
    it "defaults to assistant" do
      event = Riffer::StreamEvents::Timing.new(guardrail_timing)
      expect(event.role).must_equal :assistant
    end

    it "accepts custom role" do
      event = Riffer::StreamEvents::Timing.new(guardrail_timing, role: :system)
      expect(event.role).must_equal :system
    end
  end

  describe "#to_h" do
    it "includes role" do
      event = Riffer::StreamEvents::Timing.new(guardrail_timing)
      expect(event.to_h[:role]).must_equal :assistant
    end

    it "includes the timing hash with its kind" do
      event = Riffer::StreamEvents::Timing.new(tool_timing)
      expect(event.to_h[:timing][:kind]).must_equal :tool
      expect(event.to_h[:timing][:tool_name]).must_equal "get_weather"
    end
  end
end
