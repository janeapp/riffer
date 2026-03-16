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
      config.tool_runtime = Riffer::ToolRuntime::Threaded
      expect(config.tool_runtime).must_equal Riffer::ToolRuntime::Threaded
    end

    it "raises for invalid tool_runtime" do
      config = Riffer::Config.new
      expect { config.tool_runtime = nil }.must_raise Riffer::ArgumentError
    end

    it "raises for string tool_runtime" do
      config = Riffer::Config.new
      expect { config.tool_runtime = "invalid" }.must_raise Riffer::ArgumentError
    end
  end

  describe "agent_runtime" do
    it "defaults to Inline instance" do
      config = Riffer::Config.new
      expect(config.agent_runtime).must_be_instance_of Riffer::AgentRuntime::Inline
    end

    it "allows setting agent_runtime" do
      config = Riffer::Config.new
      config.agent_runtime = Riffer::AgentRuntime::Threaded
      expect(config.agent_runtime).must_equal Riffer::AgentRuntime::Threaded
    end

    it "raises for invalid agent_runtime" do
      config = Riffer::Config.new
      expect { config.agent_runtime = nil }.must_raise Riffer::ArgumentError
    end

    it "raises for string agent_runtime" do
      config = Riffer::Config.new
      expect { config.agent_runtime = "invalid" }.must_raise Riffer::ArgumentError
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
