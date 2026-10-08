# frozen_string_literal: true

require "test_helper"
require "tmpdir"

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

  describe "catalog_files" do
    it "defaults to an empty list and an empty catalog" do
      config = Riffer::Config.new

      expect(config.catalog_files).must_equal []
      expect(config.catalog.empty?).must_equal true
    end

    it "stores Pathnames as Strings" do
      config = Riffer::Config.new
      config.catalog_files = [Pathname.new("config/riffer/models.json")]

      expect(config.catalog_files).must_equal ["config/riffer/models.json"]
    end

    it "raises when not an Array of paths" do
      config = Riffer::Config.new

      expect { config.catalog_files = "config/riffer/models.json" }.must_raise Riffer::ArgumentError
      expect { config.catalog_files = [1] }.must_raise Riffer::ArgumentError
    end

    it "drops the built catalog when the files change" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "models.json")
        models = { "openai/gpt-5.1" => { pricing: { input: 1, output: 2 } } }
        File.write(path, JSON.generate({ version: 1, models: models }))
        config = Riffer::Config.new
        config.catalog
        config.catalog_files = [path]

        expect(config.catalog.rates_for("openai/gpt-5.1")).wont_be_nil
      end
    end
  end
end
