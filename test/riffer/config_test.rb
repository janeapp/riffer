# frozen_string_literal: true

require "test_helper"

describe Riffer::Config do
  describe "#initialize" do
    it "initializes every section" do
      config = Riffer::Config.new
      sections = %i[
        amazon_bedrock anthropic azure_openai gemini openai openrouter evals mcp skills tracing files pricing
      ]

      expect(sections.map { |section| config.public_send(section).class }).must_equal [
        Riffer::Config::AmazonBedrock,
        Riffer::Config::Anthropic,
        Riffer::Config::AzureOpenAI,
        Riffer::Config::Gemini,
        Riffer::Config::OpenAI,
        Riffer::Config::OpenRouter,
        Riffer::Config::Evals,
        Riffer::Config::Mcp,
        Riffer::Config::Skills,
        Riffer::Config::Tracing,
        Riffer::Config::Files,
        Riffer::Config::Pricing,
      ]
    end
  end

  describe "tool_runtime" do
    it "defaults to Inline instance" do
      config = Riffer::Config.new

      expect(config.tool_runtime).must_be_instance_of Riffer::Tools::Runtime::Inline
    end

    it "allows setting tool_runtime" do
      config = Riffer::Config.new
      config.tool_runtime = Riffer::Tools::Runtime::Threaded

      expect(config.tool_runtime).must_equal Riffer::Tools::Runtime::Threaded
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

  describe "message_id_strategy" do
    it "defaults to :none" do
      config = Riffer::Config.new

      expect(config.message_id_strategy).must_equal :none
    end

    it "accepts :none" do
      config = Riffer::Config.new
      config.message_id_strategy = :none

      expect(config.message_id_strategy).must_equal :none
    end

    it "accepts :uuid" do
      config = Riffer::Config.new
      config.message_id_strategy = :uuid

      expect(config.message_id_strategy).must_equal :uuid
    end

    it "accepts :uuidv7" do
      config = Riffer::Config.new
      config.message_id_strategy = :uuidv7

      expect(config.message_id_strategy).must_equal :uuidv7
    end

    it "raises for unknown symbols" do
      config = Riffer::Config.new

      expect { config.message_id_strategy = :ulid }.must_raise Riffer::ArgumentError
    end

    it "raises for string values" do
      config = Riffer::Config.new

      expect { config.message_id_strategy = "uuid" }.must_raise Riffer::ArgumentError
    end

    it "raises for nil" do
      config = Riffer::Config.new

      expect { config.message_id_strategy = nil }.must_raise Riffer::ArgumentError
    end
  end
end
