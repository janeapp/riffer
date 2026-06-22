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

  describe "tracing namespace" do
    it "initializes enabled to true" do
      config = Riffer::Config.new
      expect(config.tracing.enabled).must_equal true
    end

    it "coerces a 'false' string for enabled" do
      config = Riffer::Config.new
      config.tracing.enabled = "false"
      expect(config.tracing.enabled).must_equal false
    end

    it "coerces a 'true' string for enabled" do
      config = Riffer::Config.new
      config.tracing.enabled = "true"
      expect(config.tracing.enabled).must_equal true
    end

    it "raises for an unrecognized enabled value" do
      config = Riffer::Config.new
      expect { config.tracing.enabled = "yes" }.must_raise Riffer::ArgumentError
    end

    it "initializes capture_messages to false" do
      config = Riffer::Config.new
      expect(config.tracing.capture_messages).must_equal false
    end

    it "coerces a 'true' string for capture_messages" do
      config = Riffer::Config.new
      config.tracing.capture_messages = "true"
      expect(config.tracing.capture_messages).must_equal true
    end

    it "raises for an unrecognized capture_messages value" do
      config = Riffer::Config.new
      expect { config.tracing.capture_messages = "yes" }.must_raise Riffer::ArgumentError
    end

    it "initializes backend to nil" do
      config = Riffer::Config.new
      expect(config.tracing.backend).must_be_nil
    end

    it "accepts a backend satisfying the tracing contract" do
      config = Riffer::Config.new
      backend = Object.new
      def backend.in_span(*) = yield
      def backend.current_context = nil
      def backend.with_context(_) = yield
      config.tracing.backend = backend
      expect(config.tracing.backend).must_be_same_as backend
    end

    it "allows clearing the backend with nil" do
      config = Riffer::Config.new
      config.tracing.backend = nil
      expect(config.tracing.backend).must_be_nil
    end

    it "raises for a backend missing every contract method" do
      config = Riffer::Config.new
      expect { config.tracing.backend = Object.new }.must_raise Riffer::ArgumentError
    end

    it "raises for a backend that responds to in_span but not the context methods" do
      config = Riffer::Config.new
      backend = Object.new
      def backend.in_span(*) = yield
      expect { config.tracing.backend = backend }.must_raise Riffer::ArgumentError
    end
  end

  describe "metrics namespace" do
    it "initializes enabled to true" do
      config = Riffer::Config.new
      expect(config.metrics.enabled).must_equal true
    end

    it "coerces a 'false' string for enabled" do
      config = Riffer::Config.new
      config.metrics.enabled = "false"
      expect(config.metrics.enabled).must_equal false
    end

    it "coerces a 'true' string for enabled" do
      config = Riffer::Config.new
      config.metrics.enabled = "true"
      expect(config.metrics.enabled).must_equal true
    end

    it "raises for an unrecognized enabled value" do
      config = Riffer::Config.new
      expect { config.metrics.enabled = "yes" }.must_raise Riffer::ArgumentError
    end

    it "initializes backend to nil" do
      config = Riffer::Config.new
      expect(config.metrics.backend).must_be_nil
    end

    it "accepts a backend that responds to record_histogram" do
      config = Riffer::Config.new
      backend = Object.new.tap { |o| def o.record_histogram(*, **) = nil }
      config.metrics.backend = backend
      expect(config.metrics.backend).must_be_same_as backend
    end

    it "allows clearing the backend with nil" do
      config = Riffer::Config.new
      config.metrics.backend = nil
      expect(config.metrics.backend).must_be_nil
    end

    it "raises for a backend that does not respond to record_histogram" do
      config = Riffer::Config.new
      expect { config.metrics.backend = Object.new }.must_raise Riffer::ArgumentError
    end
  end
end
