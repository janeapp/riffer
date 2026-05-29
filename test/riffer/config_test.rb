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

  describe "openrouter namespace" do
    it "initializes with nil api_key" do
      config = Riffer::Config.new
      expect(config.openrouter.api_key).must_be_nil
    end

    it "allows setting the api_key" do
      config = Riffer::Config.new
      config.openrouter.api_key = "sk-or-test"
      expect(config.openrouter.api_key).must_equal "sk-or-test"
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

  describe "experimental_history_healing" do
    it "defaults to false" do
      expect(Riffer::Config.new.experimental_history_healing).must_equal false
    end

    it "accepts true and false" do
      config = Riffer::Config.new
      config.experimental_history_healing = true
      expect(config.experimental_history_healing).must_equal true
      config.experimental_history_healing = false
      expect(config.experimental_history_healing).must_equal false
    end

    it "coerces ENV-style truthy strings" do
      config = Riffer::Config.new
      config.experimental_history_healing = "true"
      expect(config.experimental_history_healing).must_equal true
      config.experimental_history_healing = "1"
      expect(config.experimental_history_healing).must_equal true
      config.experimental_history_healing = 1
      expect(config.experimental_history_healing).must_equal true
    end

    it "coerces ENV-style falsy strings" do
      config = Riffer::Config.new
      config.experimental_history_healing = true
      config.experimental_history_healing = "false"
      expect(config.experimental_history_healing).must_equal false
      config.experimental_history_healing = "0"
      expect(config.experimental_history_healing).must_equal false
      config.experimental_history_healing = 0
      expect(config.experimental_history_healing).must_equal false
    end

    it "treats nil as false (ENV-not-set)" do
      config = Riffer::Config.new
      config.experimental_history_healing = true
      config.experimental_history_healing = nil
      expect(config.experimental_history_healing).must_equal false
    end

    it "raises for other strings" do
      config = Riffer::Config.new
      expect { config.experimental_history_healing = "yes" }.must_raise Riffer::ArgumentError
    end

    it "raises for unrelated values" do
      config = Riffer::Config.new
      expect { config.experimental_history_healing = :on }.must_raise Riffer::ArgumentError
    end
  end

  describe "mcp namespace" do
    it "initializes credentials to nil" do
      config = Riffer::Config.new
      expect(config.mcp.credentials).must_be_nil
    end

    it "allows setting credentials proc" do
      config = Riffer::Config.new
      cred = ->(manifest:, matched_tags:, context:) { {} }
      config.mcp.credentials = cred
      expect(config.mcp.credentials).must_equal cred
    end
  end
end
