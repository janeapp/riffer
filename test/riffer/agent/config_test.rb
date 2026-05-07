# frozen_string_literal: true

require "test_helper"

# Named fixtures for the round-trip tests — Object.const_get requires real
# constants, so anonymous classes won't survive serialization.
module AgentConfigTestFixtures
  class HelloTool < Riffer::Tool
    identifier "hello_tool"
    description "Says hello."

    def call(context:)
      text("hello")
    end
  end

  class GoodbyeTool < Riffer::Tool
    identifier "goodbye_tool"
    description "Says goodbye."

    def call(context:)
      text("bye")
    end
  end

  class NoopGuardrail < Riffer::Guardrail
    def process_input(messages, context:)
      pass(messages)
    end
  end
end

describe Riffer::Agent do
  describe ".to_config / .from_config" do
    it "round-trips primitive slots" do
      klass = Class.new(Riffer::Agent) do
        identifier "test-agent"
        model "mock/riffer-1"
        provider_options(api_key: "k")
        model_options(reasoning: "medium")
        max_steps 5
      end

      config = klass.to_config
      restored = Riffer::Agent.from_config(config)

      expect(restored.identifier).must_equal "test-agent"
      expect(restored.model).must_equal "mock/riffer-1"
      expect(restored.provider_options).must_equal({api_key: "k"})
      expect(restored.model_options).must_equal({reasoning: "medium"})
      expect(restored.max_steps).must_equal 5
    end

    it "produces a JSON-safe hash" do
      klass = Class.new(Riffer::Agent) do
        identifier "j"
        model "mock/riffer-1"
        max_steps 3
      end
      JSON.parse(klass.to_config.to_json) # must not raise
    end

    it "resolves the model Proc against context" do
      klass = Class.new(Riffer::Agent) do
        identifier "p"
        model ->(ctx) { "mock/#{ctx[:variant]}" }
      end

      config = klass.to_config(context: {variant: "fast"})
      expect(config[:model]).must_equal "mock/fast"
    end

    it "round-trips Float::INFINITY for max_steps" do
      klass = Class.new(Riffer::Agent) do
        identifier "i"
        model "mock/riffer-1"
        max_steps Float::INFINITY
      end

      restored = Riffer::Agent.from_config(klass.to_config)
      expect(restored.max_steps).must_equal Float::INFINITY
    end

    it "round-trips structured_output" do
      klass = Class.new(Riffer::Agent) do
        identifier "s"
        model "mock/riffer-1"
        structured_output do
          required :sentiment, String, enum: ["positive", "negative"]
          optional :score, Float
        end
      end

      restored = Riffer::Agent.from_config(klass.to_config)
      params = restored.structured_output.parameters
      expect(params.map(&:name)).must_equal [:sentiment, :score]
      expect(params[0].enum).must_equal ["positive", "negative"]
      expect(params[1].type).must_equal Float
    end

    it "round-trips tools as class names and resolves a uses_tools Proc" do
      hello = AgentConfigTestFixtures::HelloTool
      bye = AgentConfigTestFixtures::GoodbyeTool

      klass = Class.new(Riffer::Agent) do
        identifier "t"
        model "mock/riffer-1"
        uses_tools ->(ctx) { ctx[:include_bye] ? [hello, bye] : [hello] }
      end

      config = klass.to_config(context: {include_bye: true})
      expect(config[:tools]).must_equal [
        "AgentConfigTestFixtures::HelloTool",
        "AgentConfigTestFixtures::GoodbyeTool"
      ]

      restored = Riffer::Agent.from_config(config)
      expect(restored.uses_tools).must_equal [hello, bye]
    end

    it "round-trips tool_runtime as a class reference" do
      klass = Class.new(Riffer::Agent) do
        identifier "tr"
        model "mock/riffer-1"
        tool_runtime Riffer::ToolRuntime::Inline
      end

      config = klass.to_config
      expect(config[:tool_runtime]).must_equal "Riffer::ToolRuntime::Inline"

      restored = Riffer::Agent.from_config(config)
      expect(restored.tool_runtime).must_equal Riffer::ToolRuntime::Inline
    end

    it "raises SerializationError when tool_runtime is an instance" do
      klass = Class.new(Riffer::Agent) do
        identifier "tri"
        model "mock/riffer-1"
        tool_runtime Riffer::ToolRuntime::Inline.new
      end

      err = expect { klass.to_config }.must_raise Riffer::SerializationError
      expect(err.message).must_match(/tool_runtime/)
    end

    it "round-trips mcp_configs" do
      klass = Class.new(Riffer::Agent) do
        identifier "m"
        model "mock/riffer-1"
        use_mcp :github
        use_mcp :search
      end

      config = klass.to_config
      expect(config[:mcp_configs]).must_equal [{tags: ["github"]}, {tags: ["search"]}]

      restored = Riffer::Agent.from_config(config)
      expect(restored.mcp_configs).must_equal [{tags: [:github]}, {tags: [:search]}]
    end

    it "round-trips guardrails with class name and options" do
      gr = AgentConfigTestFixtures::NoopGuardrail

      klass = Class.new(Riffer::Agent) do
        identifier "g"
        model "mock/riffer-1"
        guardrail :before, with: gr, threshold: 0.5
        guardrail :after, with: gr
      end

      config = klass.to_config
      expect(config[:guardrails][:before].first[:class]).must_equal gr.name
      expect(config[:guardrails][:before].first[:options]).must_equal({threshold: 0.5})

      restored = Riffer::Agent.from_config(config)
      expect(restored.guardrails_for(:before).first[:class]).must_equal gr
      expect(restored.guardrails_for(:before).first[:options]).must_equal({threshold: 0.5})
      expect(restored.guardrails_for(:after).first[:class]).must_equal gr
    end

    it "carries the skill activate tool through the tools list when skills are configured" do
      klass = Class.new(Riffer::Agent) do
        identifier "sk"
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      config = klass.to_config(context: nil)
      expect(config[:tools]).must_include "Riffer::Skills::ActivateTool"
    end

    it "omits instructions and skills slots from the config" do
      klass = Class.new(Riffer::Agent) do
        identifier "x"
        model "mock/riffer-1"
        instructions "You are helpful."
      end

      config = klass.to_config
      refute config.key?(:instructions), "instructions should not be in the config"
      refute config.key?(:skills), "skills should not be in the config"
    end

    it "end-to-end: serialize sender, ship messages, run on receiver" do
      hello = AgentConfigTestFixtures::HelloTool

      sender_class = Class.new(Riffer::Agent) do
        identifier "e2e"
        model "mock/riffer-1"
        instructions ->(ctx) { "You are helping #{ctx[:name]}." }
        uses_tools [hello]
      end

      sender = sender_class.new
      ctx = {name: "Jane"}

      messages = [
        sender.generate_instruction_message(context: ctx),
        Riffer::Messages::User.new("Hi")
      ].compact

      payload = {
        config: sender_class.to_config(context: ctx),
        messages: messages.map(&:to_h)
      }

      # round-trip through JSON to prove it's portable
      wire = JSON.parse(payload.to_json, symbolize_names: true)
      receiver_class = Riffer::Agent.from_config(wire[:config])
      receiver = receiver_class.new

      provider = receiver.send(:provider_instance)
      provider.stub_response("Hello Jane!")

      result = receiver.generate(wire[:messages])

      expect(result.content).must_equal "Hello Jane!"
      sent = provider.calls.first[:messages]
      expect(sent.first[:role]).must_equal :system
      expect(sent.first[:content]).must_equal "You are helping Jane."
      expect(sent.last[:role]).must_equal :user
    end
  end
end
