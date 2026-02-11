# frozen_string_literal: true

require "test_helper"

describe Riffer::Guardrails::Result do
  describe ".pass" do
    it "creates a pass result" do
      result = Riffer::Guardrails::Result.pass("data")
      expect(result.type).must_equal :pass
    end

    it "stores the data" do
      result = Riffer::Guardrails::Result.pass("test data")
      expect(result.data).must_equal "test data"
    end
  end

  describe ".transform" do
    it "creates a transform result" do
      result = Riffer::Guardrails::Result.transform("transformed")
      expect(result.type).must_equal :transform
    end

    it "stores the data" do
      result = Riffer::Guardrails::Result.transform("new data")
      expect(result.data).must_equal "new data"
    end
  end

  describe ".block" do
    it "creates a block result" do
      result = Riffer::Guardrails::Result.block("blocked")
      expect(result.type).must_equal :block
    end

    it "stores the reason in data" do
      result = Riffer::Guardrails::Result.block("PII detected")
      expect(result.data).must_equal "PII detected"
    end

    it "stores metadata" do
      result = Riffer::Guardrails::Result.block("blocked", metadata: {key: "value"})
      expect(result.metadata).must_equal({key: "value"})
    end
  end

  describe "#pass?" do
    it "returns true for pass results" do
      result = Riffer::Guardrails::Result.pass("data")
      expect(result.pass?).must_equal true
    end

    it "returns false for transform results" do
      result = Riffer::Guardrails::Result.transform("data")
      expect(result.pass?).must_equal false
    end

    it "returns false for block results" do
      result = Riffer::Guardrails::Result.block("reason")
      expect(result.pass?).must_equal false
    end
  end

  describe "#transform?" do
    it "returns true for transform results" do
      result = Riffer::Guardrails::Result.transform("data")
      expect(result.transform?).must_equal true
    end

    it "returns false for pass results" do
      result = Riffer::Guardrails::Result.pass("data")
      expect(result.transform?).must_equal false
    end

    it "returns false for block results" do
      result = Riffer::Guardrails::Result.block("reason")
      expect(result.transform?).must_equal false
    end
  end

  describe "#block?" do
    it "returns true for block results" do
      result = Riffer::Guardrails::Result.block("reason")
      expect(result.block?).must_equal true
    end

    it "returns false for pass results" do
      result = Riffer::Guardrails::Result.pass("data")
      expect(result.block?).must_equal false
    end

    it "returns false for transform results" do
      result = Riffer::Guardrails::Result.transform("data")
      expect(result.block?).must_equal false
    end
  end

  describe "invalid type" do
    it "raises error for invalid type" do
      error = expect { Riffer::Guardrails::Result.new(:invalid, "data") }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Invalid result type/)
    end
  end
end
