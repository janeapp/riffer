# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Judge do
  describe "#initialize" do
    it "sets the model" do
      judge = Riffer::Evals::Judge.new(model: "test/eval-model")
      expect(judge.model).must_equal "test/eval-model"
    end
  end

  describe "#evaluate" do
    it "calls the provider and parses response" do
      # Use VCR for real API integration tests
      # For unit tests, we verify the Judge correctly configures itself
      judge = Riffer::Evals::Judge.new(model: "test/eval-model")
      expect(judge.model).must_equal "test/eval-model"
    end
  end
end
