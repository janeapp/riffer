# frozen_string_literal: true

require "test_helper"

describe Riffer::Config::Evals do
  describe "#judge_model" do
    it "initializes to nil" do
      expect(Riffer::Config::Evals.new.judge_model).must_be_nil
    end

    it "accepts a provider/model id" do
      evals = Riffer::Config::Evals.new
      evals.judge_model = "anthropic/claude-sonnet-4-20250514"

      expect(evals.judge_model).must_equal "anthropic/claude-sonnet-4-20250514"
    end

    it "allows clearing with nil" do
      evals = Riffer::Config::Evals.new
      evals.judge_model = "openai/gpt-4"
      evals.judge_model = nil

      expect(evals.judge_model).must_be_nil
    end

    it "raises for a model id without a provider segment" do
      evals = Riffer::Config::Evals.new
      error = expect { evals.judge_model = "gpt-4" }.must_raise Riffer::ArgumentError

      expect(error.message).must_match(/^judge_model /)
    end

    it "raises for a non-string" do
      evals = Riffer::Config::Evals.new

      expect { evals.judge_model = :"openai/gpt-4" }.must_raise Riffer::ArgumentError
    end
  end
end
