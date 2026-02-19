# frozen_string_literal: true

require "test_helper"

describe Riffer::StructuredOutput::Result do
  describe "#success?" do
    it "returns true when no error" do
      result = Riffer::StructuredOutput::Result.new(object: {sentiment: "positive"})
      expect(result.success?).must_equal true
    end

    it "returns false when error present" do
      result = Riffer::StructuredOutput::Result.new(error: "something went wrong")
      expect(result.success?).must_equal false
    end
  end

  describe "#failure?" do
    it "returns false when no error" do
      result = Riffer::StructuredOutput::Result.new(object: {sentiment: "positive"})
      expect(result.failure?).must_equal false
    end

    it "returns true when error present" do
      result = Riffer::StructuredOutput::Result.new(error: "something went wrong")
      expect(result.failure?).must_equal true
    end
  end

  describe "#object" do
    it "returns the validated object" do
      result = Riffer::StructuredOutput::Result.new(object: {sentiment: "positive", score: 0.9})
      expect(result.object).must_equal({sentiment: "positive", score: 0.9})
    end

    it "returns nil on failure" do
      result = Riffer::StructuredOutput::Result.new(error: "something went wrong")
      expect(result.object).must_be_nil
    end
  end

  describe "#error" do
    it "returns the error message" do
      result = Riffer::StructuredOutput::Result.new(error: "parse failed")
      expect(result.error).must_equal "parse failed"
    end

    it "returns nil on success" do
      result = Riffer::StructuredOutput::Result.new(object: {sentiment: "positive"})
      expect(result.error).must_be_nil
    end
  end
end
