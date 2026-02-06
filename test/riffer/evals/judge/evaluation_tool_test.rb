# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Judge::EvaluationTool do
  describe ".identifier" do
    it "has the correct identifier" do
      expect(Riffer::Evals::Judge::EvaluationTool.identifier).must_equal "evaluation"
    end
  end

  describe ".description" do
    it "has a description" do
      expect(Riffer::Evals::Judge::EvaluationTool.description).wont_be_nil
    end
  end

  describe ".parameters_schema" do
    it "requires score as a number" do
      schema = Riffer::Evals::Judge::EvaluationTool.parameters_schema
      expect(schema[:properties]["score"][:type]).must_equal "number"
      expect(schema[:required]).must_include "score"
    end

    it "requires reason as a string" do
      schema = Riffer::Evals::Judge::EvaluationTool.parameters_schema
      expect(schema[:properties]["reason"][:type]).must_equal "string"
      expect(schema[:required]).must_include "reason"
    end
  end

  describe "#call" do
    it "returns a JSON response with score and reason" do
      tool = Riffer::Evals::Judge::EvaluationTool.new
      response = tool.call(context: nil, score: 0.85, reason: "Good response.")

      expect(response).must_be_instance_of Riffer::Tools::Response
      parsed = JSON.parse(response.content)
      expect(parsed["score"]).must_equal 0.85
      expect(parsed["reason"]).must_equal "Good response."
    end
  end
end
