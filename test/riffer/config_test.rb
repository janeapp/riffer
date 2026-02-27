# frozen_string_literal: true

require "test_helper"

describe Riffer::Config do
  describe "#initialize" do
    it "initializes openai namespace" do
      config = Riffer::Config.new
      expect(config.openai).must_be_kind_of Struct
    end

    it "initializes with nil openai api_key" do
      config = Riffer::Config.new
      expect(config.openai.api_key).must_be_nil
    end
  end

  describe "openai namespace" do
    it "allows setting the api_key" do
      config = Riffer::Config.new
      config.openai.api_key = "test-key"
      expect(config.openai.api_key).must_equal "test-key"
    end
  end

  describe "tool_runtime" do
    it "defaults to Inline instance" do
      config = Riffer::Config.new
      expect(config.tool_runtime).must_be_instance_of Riffer::ToolRuntime::Inline
    end

    it "allows setting tool_runtime" do
      config = Riffer::Config.new
      config.tool_runtime = :threaded
      expect(config.tool_runtime).must_equal :threaded
    end
  end

  describe "evals namespace" do
    it "initializes with nil judge_model" do
      config = Riffer::Config.new
      expect(config.evals.judge_model).must_be_nil
    end

    it "allows setting the judge_model" do
      config = Riffer::Config.new
      config.evals.judge_model = "anthropic/claude-sonnet-4-20250514"
      expect(config.evals.judge_model).must_equal "anthropic/claude-sonnet-4-20250514"
    end
  end
end
