# frozen_string_literal: true

require "test_helper"

describe Riffer::Catalog::Rates do
  describe ".build" do
    it "coerces integer rates to floats" do
      rates = Riffer::Catalog::Rates.new(input: 3, output: 15, cache_read: 1)

      expect([rates.input, rates.output, rates.cache_read, rates.cache_write]).must_equal [3.0, 15.0, 1.0, nil]
    end

    it "raises on a negative rate" do
      error = expect { Riffer::Catalog::Rates.new(input: -1, output: 15) }.must_raise Riffer::ArgumentError

      expect(error.message).must_equal "input rate must be a non-negative number, got -1"
    end

    it "raises on a non-numeric optional rate" do
      error = expect { Riffer::Catalog::Rates.new(input: 1, output: 15, cache_write: "2") }.must_raise Riffer::ArgumentError

      expect(error.message).must_equal 'cache_write rate must be a non-negative number, got "2"'
    end

    it "raises on an infinite rate" do
      expect { Riffer::Catalog::Rates.new(input: Float::INFINITY, output: 15) }.must_raise Riffer::ArgumentError
    end
  end

  describe "#cost_for" do
    it "prices input and output at the per-million rates" do
      rates = Riffer::Catalog::Rates.new(input: 3.0, output: 15.0)
      cost = rates.cost_for(input_tokens: 2_000_000, output_tokens: 1_000_000)

      expect(cost).must_equal 21.0
    end

    it "subtracts the cache subsets and prices them at their own rates" do
      rates = Riffer::Catalog::Rates.new(input: 3.0, output: 15.0, cache_read: 1.0, cache_write: 5.0)
      cost = rates.cost_for(
        input_tokens: 4_000_000,
        output_tokens: 0,
        cache_read_tokens: 1_000_000,
        cache_write_tokens: 1_000_000,
      )

      expect(cost).must_equal 12.0
    end

    it "bills cache tokens at the input rate when no cache rate is set" do
      rates = Riffer::Catalog::Rates.new(input: 3.0, output: 15.0)
      cost = rates.cost_for(input_tokens: 2_000_000, output_tokens: 0, cache_read_tokens: 1_000_000)

      expect(cost).must_equal 6.0
    end

    it "treats nil cache buckets as zero" do
      rates = Riffer::Catalog::Rates.new(input: 3.0, output: 15.0)
      cost = rates.cost_for(input_tokens: 1_000_000, output_tokens: 1_000_000)

      expect(cost).must_equal 18.0
    end

    it "clamps the uncached portion at zero rather than going negative" do
      rates = Riffer::Catalog::Rates.new(input: 4.0, output: 15.0, cache_read: 1.0, cache_write: 1.0)
      cost = rates.cost_for(
        input_tokens: 2_000_000,
        output_tokens: 0,
        cache_read_tokens: 1_500_000,
        cache_write_tokens: 1_500_000,
      )

      expect(cost).must_equal 3.0
    end
  end
end
