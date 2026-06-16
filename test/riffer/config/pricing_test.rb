# frozen_string_literal: true

require "test_helper"

describe Riffer::Config::Pricing do
  describe "#empty?" do
    it "is true before any rates are registered" do
      expect(Riffer::Config::Pricing.new.empty?).must_equal true
    end

    it "is false after a model is registered" do
      pricing = Riffer::Config::Pricing.new
      pricing.set("openai/gpt-4", input: 30.0, output: 60.0)
      expect(pricing.empty?).must_equal false
    end
  end

  describe "#set" do
    it "registers rates retrievable by model id" do
      pricing = Riffer::Config::Pricing.new
      pricing.set("openai/gpt-4", input: 30.0, output: 60.0)
      expect(pricing.rates_for("openai/gpt-4").input).must_equal 30.0
    end

    it "defaults cache rates to nil when omitted" do
      pricing = Riffer::Config::Pricing.new
      pricing.set("openai/gpt-4", input: 30.0, output: 60.0)
      expect(pricing.rates_for("openai/gpt-4").cache_read).must_be_nil
    end

    it "coerces integer rates to floats" do
      pricing = Riffer::Config::Pricing.new
      pricing.set("openai/gpt-4", input: 30, output: 60)
      expect(pricing.rates_for("openai/gpt-4").input).must_equal 30.0
    end

    it "overwrites an earlier registration for the same model" do
      pricing = Riffer::Config::Pricing.new
      pricing.set("openai/gpt-4", input: 30.0, output: 60.0)
      pricing.set("openai/gpt-4", input: 10.0, output: 20.0)
      expect(pricing.rates_for("openai/gpt-4").input).must_equal 10.0
    end

    it "raises when the model id has no provider segment" do
      pricing = Riffer::Config::Pricing.new
      expect { pricing.set("gpt-4", input: 30.0, output: 60.0) }.must_raise Riffer::ArgumentError
    end

    it "raises when a model id segment is empty" do
      pricing = Riffer::Config::Pricing.new
      expect { pricing.set("openai/", input: 30.0, output: 60.0) }.must_raise Riffer::ArgumentError
    end

    it "raises on a negative rate" do
      pricing = Riffer::Config::Pricing.new
      expect { pricing.set("openai/gpt-4", input: -1.0, output: 60.0) }.must_raise Riffer::ArgumentError
    end

    it "raises on a non-numeric rate" do
      pricing = Riffer::Config::Pricing.new
      expect { pricing.set("openai/gpt-4", input: "30.0", output: 60.0) }.must_raise Riffer::ArgumentError
    end
  end

  describe "#rates_for" do
    it "returns nil for an unregistered model" do
      expect(Riffer::Config::Pricing.new.rates_for("openai/gpt-4")).must_be_nil
    end
  end
end

describe Riffer::Config::Pricing::Rates do
  describe "#cost_for" do
    it "prices input and output at the per-million rates" do
      rates = Riffer::Config::Pricing::Rates.new(input: 3.0, output: 15.0)
      cost = rates.cost_for(input_tokens: 2_000_000, output_tokens: 1_000_000)
      expect(cost).must_equal 21.0
    end

    it "subtracts the cache subsets and prices them at their own rates" do
      rates = Riffer::Config::Pricing::Rates.new(input: 3.0, output: 15.0, cache_read: 1.0, cache_write: 5.0)
      cost = rates.cost_for(input_tokens: 4_000_000, output_tokens: 0, cache_read_tokens: 1_000_000, cache_write_tokens: 1_000_000)
      expect(cost).must_equal 12.0
    end

    it "bills cache tokens at the input rate when no cache rate is set" do
      rates = Riffer::Config::Pricing::Rates.new(input: 3.0, output: 15.0)
      cost = rates.cost_for(input_tokens: 2_000_000, output_tokens: 0, cache_read_tokens: 1_000_000)
      expect(cost).must_equal 6.0
    end

    it "treats nil cache buckets as zero" do
      rates = Riffer::Config::Pricing::Rates.new(input: 3.0, output: 15.0)
      cost = rates.cost_for(input_tokens: 1_000_000, output_tokens: 1_000_000)
      expect(cost).must_equal 18.0
    end

    it "clamps the uncached portion at zero rather than going negative" do
      rates = Riffer::Config::Pricing::Rates.new(input: 4.0, output: 15.0, cache_read: 1.0, cache_write: 1.0)
      cost = rates.cost_for(input_tokens: 2_000_000, output_tokens: 0, cache_read_tokens: 1_500_000, cache_write_tokens: 1_500_000)
      expect(cost).must_equal 3.0
    end
  end
end
