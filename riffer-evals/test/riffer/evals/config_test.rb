# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Config do
  describe "#judge_model" do
    it "initializes to nil" do
      expect(Riffer::Evals::Config.new.judge_model).must_be_nil
    end

    it "accepts a provider/model id" do
      config = Riffer::Evals::Config.new
      config.judge_model = "anthropic/claude-sonnet-4-20250514"

      expect(config.judge_model).must_equal "anthropic/claude-sonnet-4-20250514"
    end

    it "allows clearing with nil" do
      config = Riffer::Evals::Config.new
      config.judge_model = "openai/gpt-4"
      config.judge_model = nil

      expect(config.judge_model).must_be_nil
    end

    it "raises for a model id without a provider segment" do
      config = Riffer::Evals::Config.new
      error = expect { config.judge_model = "gpt-4" }.must_raise Riffer::ArgumentError

      expect(error.message).must_equal "judge_model must be in \"provider/model\" form, got \"gpt-4\""
    end

    it "raises for a blank model segment" do
      config = Riffer::Evals::Config.new

      expect { config.judge_model = "openai/ " }.must_raise Riffer::ArgumentError
    end

    it "raises for a non-string" do
      config = Riffer::Evals::Config.new

      expect { config.judge_model = :"openai/gpt-4" }.must_raise Riffer::ArgumentError
    end
  end
end

describe Riffer::Evals do
  describe ".config" do
    it "returns the same config each time" do
      expect(Riffer::Evals.config).must_be_same_as Riffer::Evals.config
    end
  end

  describe ".configure" do
    it "yields the config" do
      Riffer::Evals.configure { |config| config.judge_model = "openai/gpt-4" }

      expect(Riffer::Evals.config.judge_model).must_equal "openai/gpt-4"
    ensure
      Riffer::Evals.config.judge_model = nil
    end
  end
end
