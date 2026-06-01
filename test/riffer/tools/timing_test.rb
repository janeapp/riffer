# frozen_string_literal: true

require "test_helper"

describe Riffer::Tools::Timing do
  def build(**overrides)
    defaults = {tool_name: "get_weather", call_id: "call_1", duration: 0.5, error_type: nil}
    Riffer::Tools::Timing.new(**defaults.merge(overrides))
  end

  describe "#initialize" do
    it "stores the tool name" do
      expect(build.tool_name).must_equal "get_weather"
    end

    it "stores the call id" do
      expect(build(call_id: "call_9").call_id).must_equal "call_9"
    end

    it "stores the duration" do
      expect(build(duration: 1.25).duration).must_equal 1.25
    end

    it "stores the error type" do
      expect(build(error_type: :timeout_error).error_type).must_equal :timeout_error
    end

    it "defaults error_type to nil" do
      expect(build.error_type).must_be_nil
    end
  end

  describe "#kind" do
    it "is :tool" do
      expect(build.kind).must_equal :tool
    end
  end

  describe "#success?" do
    it "is true when error_type is nil" do
      expect(build.success?).must_equal true
    end

    it "is false when error_type is set" do
      expect(build(error_type: :execution_error).success?).must_equal false
    end
  end

  describe "#duration_ms" do
    it "converts seconds to milliseconds" do
      expect(build(duration: 0.5).duration_ms).must_equal 500.0
    end
  end

  describe "#to_h" do
    it "includes the kind, tool name, call id, and error type" do
      hash = build(error_type: :timeout_error).to_h
      expect(hash[:kind]).must_equal :tool
      expect(hash[:tool_name]).must_equal "get_weather"
      expect(hash[:call_id]).must_equal "call_1"
      expect(hash[:duration]).must_equal 0.5
      expect(hash[:error_type]).must_equal :timeout_error
    end
  end
end
