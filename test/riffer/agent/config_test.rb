# frozen_string_literal: true

require "test_helper"

describe Riffer::Agent::Config do
  describe "defaults" do
    let(:config) { Riffer::Agent::Config.new }

    it "starts with identifier nil" do
      expect(config.identifier).must_be_nil
    end

    it "starts with model nil" do
      expect(config.model).must_be_nil
    end

    it "starts with instructions nil" do
      expect(config.instructions).must_be_nil
    end

    it "starts with model_options as empty hash" do
      expect(config.model_options).must_equal({})
    end

    it "starts with structured_output nil" do
      expect(config.structured_output).must_be_nil
    end

    it "starts with max_steps == Riffer::Agent::Config::DEFAULT_MAX_STEPS" do
      expect(config.max_steps).must_equal Riffer::Agent::Config::DEFAULT_MAX_STEPS
    end

    it "starts with tools_config nil" do
      expect(config.tools_config).must_be_nil
    end

    it "starts with mcp_configs as []" do
      expect(config.mcp_configs).must_equal []
    end

    it "starts with tool_runtime defaulted to Riffer.config.tool_runtime" do
      expect(config.tool_runtime).must_be_same_as Riffer.config.tool_runtime
    end

    it "starts with skills_config nil" do
      expect(config.skills_config).must_be_nil
    end

    it "starts with guardrails {before: [], after: []}" do
      expect(config.guardrails).must_equal(before: [], after: [])
    end
  end

  describe "#identifier=" do
    it "coerces a non-String to a String" do
      config = Riffer::Agent::Config.new
      config.identifier = :test_agent

      expect(config.identifier).must_equal "test_agent"
    end

    it "passes nil through unchanged" do
      config = Riffer::Agent::Config.new(identifier: "set")
      config.identifier = nil

      expect(config.identifier).must_be_nil
    end
  end

  describe "#structured_output=" do
    it "accepts a Riffer::Params instance" do
      params = Riffer::Params.new
      config = Riffer::Agent::Config.new
      config.structured_output = params

      expect(config.structured_output).must_be_same_as params
    end

    it "accepts nil" do
      config = Riffer::Agent::Config.new
      config.structured_output = nil

      expect(config.structured_output).must_be_nil
    end

    it "raises on a non-Params, non-nil value" do
      config = Riffer::Agent::Config.new
      error = expect { config.structured_output = { sentiment: String } }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/structured_output must be a Riffer::Params/)
    end
  end

  describe "#model=" do
    it "accepts a non-empty String" do
      config = Riffer::Agent::Config.new
      config.model = "mock/riffer-1"

      expect(config.model).must_equal "mock/riffer-1"
    end

    it "accepts a Proc" do
      proc_value = -> { "mock/riffer-1" }
      config = Riffer::Agent::Config.new
      config.model = proc_value

      expect(config.model).must_be_same_as proc_value
    end

    it "raises on non-String non-Proc" do
      config = Riffer::Agent::Config.new
      error = expect { config.model = 123 }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/model must be a String/)
    end

    it "raises on empty String" do
      config = Riffer::Agent::Config.new
      error = expect { config.model = "   " }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/model cannot be empty/)
    end
  end

  describe "#instructions=" do
    it "accepts a non-empty String" do
      config = Riffer::Agent::Config.new
      config.instructions = "Be helpful."

      expect(config.instructions).must_equal "Be helpful."
    end

    it "accepts a Proc" do
      proc_value = -> { "Be helpful." }
      config = Riffer::Agent::Config.new
      config.instructions = proc_value

      expect(config.instructions).must_be_same_as proc_value
    end

    it "raises on non-String non-Proc" do
      config = Riffer::Agent::Config.new
      error = expect { config.instructions = 123 }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/instructions must be a String/)
    end

    it "raises on empty String" do
      config = Riffer::Agent::Config.new
      error = expect { config.instructions = "   " }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/instructions cannot be empty/)
    end
  end

  describe "#initialize validation" do
    it "raises when model: kwarg is a non-String non-Proc" do
      error = expect { Riffer::Agent::Config.new(model: 123) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/model must be a String/)
    end

    it "raises when instructions: kwarg is empty" do
      error = expect { Riffer::Agent::Config.new(instructions: "  ") }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/instructions cannot be empty/)
    end
  end

  describe "#tool_runtime=" do
    it "stores a ToolRuntime subclass as-is" do
      config = Riffer::Agent::Config.new
      config.tool_runtime = Riffer::Tools::Runtime::Threaded

      expect(config.tool_runtime).must_equal Riffer::Tools::Runtime::Threaded
    end

    it "stores a ToolRuntime instance as-is" do
      runtime = Riffer::Tools::Runtime::Threaded.new
      config = Riffer::Agent::Config.new
      config.tool_runtime = runtime

      expect(config.tool_runtime).must_be_same_as runtime
    end

    it "stores a Proc as-is" do
      proc_value = ->(_) { Riffer::Tools::Runtime::Inline.new }
      config = Riffer::Agent::Config.new
      config.tool_runtime = proc_value

      expect(config.tool_runtime).must_be_same_as proc_value
    end

    it "raises on invalid values" do
      config = Riffer::Agent::Config.new
      error = expect { config.tool_runtime = "invalid" }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/tool_runtime must be a Riffer::Tools::Runtime subclass, instance, or a Proc/)
    end
  end

  describe "#initialize with tool_runtime:" do
    it "uses the explicit value when passed" do
      runtime = Riffer::Tools::Runtime::Threaded.new
      config = Riffer::Agent::Config.new(tool_runtime: runtime)

      expect(config.tool_runtime).must_be_same_as runtime
    end

    it "snapshots Riffer.config.tool_runtime when omitted" do
      original = Riffer.config.tool_runtime
      begin
        threaded = Riffer::Tools::Runtime::Threaded.new
        Riffer.config.tool_runtime = threaded

        expect(Riffer::Agent::Config.new.tool_runtime).must_be_same_as threaded
      ensure
        Riffer.config.tool_runtime = original
      end
    end
  end

  describe "#add_mcp" do
    it "appends a tag entry with the tag symbolized" do
      config = Riffer::Agent::Config.new
      config.add_mcp("weather")

      expect(config.mcp_configs).must_equal [{ tags: [:weather], progressive: true }]
    end

    it "accumulates additively across calls" do
      config = Riffer::Agent::Config.new
      config.add_mcp(:a)
      config.add_mcp(:b)

      expect(config.mcp_configs).must_equal [{ tags: [:a], progressive: true }, { tags: [:b], progressive: true }]
    end

    it "stores progressive flag for mixed progressive and non-progressive servers" do
      config = Riffer::Agent::Config.new
      config.add_mcp(:github)
      config.add_mcp(:jira, progressive: false)

      expect(config.mcp_configs).must_equal [
        { tags: [:github], progressive: true },
        { tags: [:jira], progressive: false },
      ]
    end

    it "raises ArgumentError for non-boolean progressive values" do
      config = Riffer::Agent::Config.new

      expect { config.add_mcp(:x, progressive: "false") }.must_raise Riffer::ArgumentError
    end
  end

  describe "#add_guardrail" do
    let(:guardrail_class) { Class.new(Riffer::Guardrail) }

    it ":before appends to guardrails[:before] only" do
      config = Riffer::Agent::Config.new
      config.add_guardrail(:before, klass: guardrail_class)

      expect(config.guardrails_for(:before).length).must_equal 1
      expect(config.guardrails_for(:after)).must_equal []
    end

    it ":after appends to guardrails[:after] only" do
      config = Riffer::Agent::Config.new
      config.add_guardrail(:after, klass: guardrail_class)

      expect(config.guardrails_for(:before)).must_equal []
      expect(config.guardrails_for(:after).length).must_equal 1
    end

    it ":around appends to both" do
      config = Riffer::Agent::Config.new
      config.add_guardrail(:around, klass: guardrail_class)

      expect(config.guardrails_for(:before).length).must_equal 1
      expect(config.guardrails_for(:after).length).must_equal 1
    end

    it "carries options through" do
      config = Riffer::Agent::Config.new
      config.add_guardrail(:before, klass: guardrail_class, options: { threshold: 0.5 })

      expect(config.guardrails_for(:before).first).must_equal(class: guardrail_class, options: { threshold: 0.5 })
    end

    it "raises on an invalid phase" do
      config = Riffer::Agent::Config.new
      error = expect { config.add_guardrail(:nope, klass: guardrail_class) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Invalid guardrail phase/)
    end

    it "raises when klass is not a Guardrail subclass" do
      config = Riffer::Agent::Config.new
      error = expect { config.add_guardrail(:before, klass: String) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/must be a Riffer::Guardrail subclass/)
    end
  end

  describe "#guardrails_for" do
    it "returns [] for an unknown phase" do
      expect(Riffer::Agent::Config.new.guardrails_for(:unknown)).must_equal []
    end
  end
end
