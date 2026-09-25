# frozen_string_literal: true

require "test_helper"

describe Riffer::Helpers::Validate do
  let(:helper) { Riffer::Helpers::Validate }

  describe "#optional_string" do
    it "passes a string through" do
      expect(helper.optional_string("key", attribute: "api_key")).must_equal "key"
    end

    it "passes nil through" do
      expect(helper.optional_string(nil, attribute: "api_key")).must_be_nil
    end

    it "raises for a non-string, naming the attribute" do
      error = expect { helper.optional_string(123, attribute: "api_key") }.must_raise Riffer::ArgumentError

      expect(error.message).must_match(/^api_key /)
    end

    it "leaves the rejected value out of the error message" do
      error = expect { helper.optional_string(:secret_value, attribute: "api_key") }.must_raise Riffer::ArgumentError

      expect(error.message).wont_include "secret_value"
    end
  end

  describe "#positive_integer" do
    it "passes a positive integer through" do
      expect(helper.positive_integer(5, attribute: "timeout")).must_equal 5
    end

    it "raises for zero, negatives, and non-integers" do
      raised = [0, -1, 1.5, "5", nil].map do |value|
        helper.positive_integer(value, attribute: "timeout")
      rescue Riffer::ArgumentError => e
        e.message
      end

      expect(raised).must_equal Array.new(5, "timeout must be a positive integer")
    end
  end

  describe "#runner" do
    it "passes a Riffer::Runner instance through" do
      runner = Riffer::Runner::Sequential.new

      expect(helper.runner(runner, attribute: "runner")).must_be_same_as runner
    end

    it "raises for a Riffer::Runner class rather than an instance" do
      error = expect { helper.runner(Riffer::Runner::Sequential, attribute: "runner") }.must_raise Riffer::ArgumentError

      expect(error.message).must_equal "runner must be a Riffer::Runner instance"
    end
  end

  describe "#model_id" do
    it "passes a provider/model id through" do
      expect(helper.model_id("openai/gpt-4", attribute: "judge_model")).must_equal "openai/gpt-4"
    end

    it "keeps slashes after the provider in the model segment" do
      expect(helper.model_id("openrouter/meta/llama", attribute: "judge_model")).must_equal "openrouter/meta/llama"
    end

    it "raises for an id without a provider segment" do
      error = expect { helper.model_id("gpt-4", attribute: "judge_model") }.must_raise Riffer::ArgumentError

      expect(error.message).must_equal "judge_model must be in \"provider/model\" form, got \"gpt-4\""
    end

    it "raises for a blank segment" do
      expect { helper.model_id("openai/ ", attribute: "judge_model") }.must_raise Riffer::ArgumentError
    end

    it "raises for a non-string" do
      expect { helper.model_id(:"openai/gpt-4", attribute: "judge_model") }.must_raise Riffer::ArgumentError
    end
  end
end
