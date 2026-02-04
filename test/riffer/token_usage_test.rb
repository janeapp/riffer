# frozen_string_literal: true

require "test_helper"

describe Riffer::TokenUsage do
  describe "#initialize" do
    it "sets input_tokens" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      expect(usage.input_tokens).must_equal 100
    end

    it "sets output_tokens" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      expect(usage.output_tokens).must_equal 50
    end

    it "sets cache_creation_tokens when provided" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50, cache_creation_tokens: 25)
      expect(usage.cache_creation_tokens).must_equal 25
    end

    it "sets cache_read_tokens when provided" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50, cache_read_tokens: 10)
      expect(usage.cache_read_tokens).must_equal 10
    end

    it "defaults cache_creation_tokens to nil" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      expect(usage.cache_creation_tokens).must_be_nil
    end

    it "defaults cache_read_tokens to nil" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      expect(usage.cache_read_tokens).must_be_nil
    end
  end

  describe "#total_tokens" do
    it "returns sum of input and output tokens" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      expect(usage.total_tokens).must_equal 150
    end

    it "returns zero when both are zero" do
      usage = Riffer::TokenUsage.new(input_tokens: 0, output_tokens: 0)
      expect(usage.total_tokens).must_equal 0
    end
  end

  describe "#+" do
    it "combines input_tokens" do
      usage1 = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      usage2 = Riffer::TokenUsage.new(input_tokens: 200, output_tokens: 75)
      combined = usage1 + usage2
      expect(combined.input_tokens).must_equal 300
    end

    it "combines output_tokens" do
      usage1 = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      usage2 = Riffer::TokenUsage.new(input_tokens: 200, output_tokens: 75)
      combined = usage1 + usage2
      expect(combined.output_tokens).must_equal 125
    end

    it "combines cache_creation_tokens when both have values" do
      usage1 = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50, cache_creation_tokens: 10)
      usage2 = Riffer::TokenUsage.new(input_tokens: 200, output_tokens: 75, cache_creation_tokens: 15)
      combined = usage1 + usage2
      expect(combined.cache_creation_tokens).must_equal 25
    end

    it "combines cache_read_tokens when both have values" do
      usage1 = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50, cache_read_tokens: 5)
      usage2 = Riffer::TokenUsage.new(input_tokens: 200, output_tokens: 75, cache_read_tokens: 8)
      combined = usage1 + usage2
      expect(combined.cache_read_tokens).must_equal 13
    end

    it "keeps cache_creation_tokens nil when both are nil" do
      usage1 = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      usage2 = Riffer::TokenUsage.new(input_tokens: 200, output_tokens: 75)
      combined = usage1 + usage2
      expect(combined.cache_creation_tokens).must_be_nil
    end

    it "keeps cache_read_tokens nil when both are nil" do
      usage1 = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      usage2 = Riffer::TokenUsage.new(input_tokens: 200, output_tokens: 75)
      combined = usage1 + usage2
      expect(combined.cache_read_tokens).must_be_nil
    end

    it "handles one nil cache_creation_tokens" do
      usage1 = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50, cache_creation_tokens: 10)
      usage2 = Riffer::TokenUsage.new(input_tokens: 200, output_tokens: 75)
      combined = usage1 + usage2
      expect(combined.cache_creation_tokens).must_equal 10
    end

    it "handles other nil cache_read_tokens" do
      usage1 = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      usage2 = Riffer::TokenUsage.new(input_tokens: 200, output_tokens: 75, cache_read_tokens: 8)
      combined = usage1 + usage2
      expect(combined.cache_read_tokens).must_equal 8
    end

    it "returns a new Usage instance" do
      usage1 = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      usage2 = Riffer::TokenUsage.new(input_tokens: 200, output_tokens: 75)
      combined = usage1 + usage2
      expect(combined).must_be_instance_of Riffer::TokenUsage
      expect(combined).wont_equal usage1
      expect(combined).wont_equal usage2
    end
  end

  describe "#to_h" do
    it "includes input_tokens" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      expect(usage.to_h[:input_tokens]).must_equal 100
    end

    it "includes output_tokens" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      expect(usage.to_h[:output_tokens]).must_equal 50
    end

    it "excludes cache_creation_tokens when nil" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      expect(usage.to_h.key?(:cache_creation_tokens)).must_equal false
    end

    it "excludes cache_read_tokens when nil" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      expect(usage.to_h.key?(:cache_read_tokens)).must_equal false
    end

    it "includes cache_creation_tokens when present" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50, cache_creation_tokens: 25)
      expect(usage.to_h[:cache_creation_tokens]).must_equal 25
    end

    it "includes cache_read_tokens when present" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50, cache_read_tokens: 10)
      expect(usage.to_h[:cache_read_tokens]).must_equal 10
    end

    it "returns correct hash with all values" do
      usage = Riffer::TokenUsage.new(
        input_tokens: 100,
        output_tokens: 50,
        cache_creation_tokens: 25,
        cache_read_tokens: 10
      )
      expected = {
        input_tokens: 100,
        output_tokens: 50,
        cache_creation_tokens: 25,
        cache_read_tokens: 10
      }
      expect(usage.to_h).must_equal expected
    end
  end
end
