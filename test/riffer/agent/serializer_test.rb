# frozen_string_literal: true

require "test_helper"

class SerializerWeatherTool < Riffer::Tool
  description "Look up the weather"
  params do
    required :city, String, description: "the city"
  end

  def call(context:, city:)
    text("sunny in #{city}")
  end
end

describe Riffer::Agent::Serializer do
  def build_agent_class(&block)
    Class.new(Riffer::Agent) do
      identifier "support"
      model "mock/riffer-1"
      instructions "You are helpful."
      instance_eval(&block) if block
    end
  end

  describe ".to_h" do
    it "snapshots the core data fields" do
      dict = build_agent_class.new.to_h

      expect(dict[:schema_version]).must_equal Riffer::Agent::Serializer::SCHEMA_VERSION
      expect(dict[:identifier]).must_equal "support"
      expect(dict[:model]).must_equal "mock/riffer-1"
      expect(dict[:instructions]).must_equal "You are helpful."
    end

    it "resolves Proc-based model and instructions to strings" do
      klass = Class.new(Riffer::Agent) do
        identifier "dyn"
        model -> { "mock/riffer-1" }
        instructions ->(context) { "Hi #{context[:name]}" }
      end
      dict = klass.new(context: { name: "Sam" }).to_h

      expect(dict[:model]).must_equal "mock/riffer-1"
      expect(dict[:instructions]).must_equal "Hi Sam"
    end

    it "carries provider and model options on the wire" do
      klass = build_agent_class do
        provider_options foo: "bar"
        model_options temperature: 0.2
      end
      dict = klass.new.to_h

      expect(dict[:provider_options]).must_equal({ foo: "bar" })
      expect(dict[:model_options]).must_equal({ temperature: 0.2 })
    end

    it "carries structured output as JSON Schema" do
      klass = build_agent_class do
        structured_output do
          required :answer, String
          optional :score, Float, default: 0.0
        end
      end
      dict = klass.new.to_h

      expect(dict[:structured_output][:type]).must_equal "object"
      expect(dict[:structured_output][:properties]["score"][:default]).must_equal 0.0
    end

    it "emits nil structured output when none is configured" do
      expect(build_agent_class.new.to_h[:structured_output]).must_be_nil
    end

    it "emits tools as descriptors" do
      klass = build_agent_class { uses_tools [SerializerWeatherTool] }
      descriptor = klass.new.to_h[:tools].first

      expect(descriptor[:name]).must_equal "serializer_weather_tool"
      expect(descriptor[:description]).must_equal "Look up the weather"
      expect(descriptor[:parameters_schema][:type]).must_equal "object"
      expect(descriptor[:timeout]).must_equal 10
    end

    it "encodes unlimited max_steps as -1 on the wire" do
      klass = build_agent_class { max_steps nil }

      expect(klass.new.to_h[:max_steps]).must_equal(-1)
    end

    it "carries no tool_runtime, Procs, or class references" do
      dict = build_agent_class { uses_tools [SerializerWeatherTool] }.new.to_h

      refute_includes dict.keys, :tool_runtime
      expect(dict.values.none? { |v| v.is_a?(Proc) }).must_equal true
    end
  end

  describe ".from_h" do
    it "rebuilds a runnable tool-less agent" do
      dict = build_agent_class.new.to_h
      agent = Riffer::Agent.from_h(dict, context: nil)

      expect(agent).must_be_instance_of Riffer::Agent
      expect(agent.config.identifier).must_equal "support"
      expect(agent.model_name).must_equal "riffer-1"
    end

    it "defaults context to empty when omitted" do
      dict = build_agent_class.new.to_h

      expect(Riffer::Agent.from_h(dict)).must_be_instance_of Riffer::Agent
    end

    it "round-trips through JSON with symbolized keys" do
      dict = build_agent_class { uses_tools [SerializerWeatherTool] }.new.to_h
      wire = JSON.parse(JSON.generate(dict), symbolize_names: true)
      agent = Riffer::Agent.from_h(wire, context: nil)

      expect(agent.tools.map(&:name)).must_equal ["serializer_weather_tool"]
    end

    it "reconstructs a validating structured output" do
      klass = build_agent_class do
        structured_output do
          required :answer, String
          optional :score, Float, default: 0.0
        end
      end
      agent = Riffer::Agent.from_h(klass.new.to_h, context: nil)
      result = agent.structured_output.parse_and_validate('{"answer":"yes"}')

      expect(result.object).must_equal({ answer: "yes", score: 0.0 })
    end

    it "restores provider and model options" do
      klass = build_agent_class { provider_options foo: "bar" }
      agent = Riffer::Agent.from_h(klass.new.to_h, context: nil)

      expect(agent.config.provider_options).must_equal({ foo: "bar" })
    end

    describe "max_steps" do
      it "decodes -1 as unlimited (nil)" do
        dict = build_agent_class.new.to_h.merge(max_steps: -1)

        expect(Riffer::Agent.from_h(dict, context: nil).config.max_steps).must_be_nil
      end

      it "also decodes a literal null as unlimited" do
        dict = build_agent_class.new.to_h.merge(max_steps: nil)

        expect(Riffer::Agent.from_h(dict, context: nil).config.max_steps).must_be_nil
      end

      it "decodes a finite integer" do
        dict = build_agent_class.new.to_h.merge(max_steps: 8)

        expect(Riffer::Agent.from_h(dict, context: nil).config.max_steps).must_equal 8
      end

      it "falls back to the default when the key is absent" do
        dict = build_agent_class.new.to_h
        dict.delete(:max_steps)

        expect(Riffer::Agent.from_h(dict, context: nil).config.max_steps).must_equal Riffer::Agent::Config::DEFAULT_MAX_STEPS
      end

      it "round-trips unlimited through nil -> -1 -> nil" do
        klass = build_agent_class { max_steps nil }

        rebuilt = Riffer::Agent.from_h(klass.new.to_h, context: nil)

        expect(rebuilt.config.max_steps).must_be_nil
      end
    end

    describe "session" do
      it "seeds a fresh session with the dict's instructions when omitted" do
        dict = build_agent_class.new.to_h
        agent = Riffer::Agent.from_h(dict, context: nil)

        expect(agent.session.messages.map(&:role)).must_equal [:system]
        expect(agent.session.messages.first.content).must_equal "You are helpful."
      end

      it "uses a provided session verbatim to seed conversation history" do
        dict = build_agent_class.new.to_h
        history = [
          Riffer::Messages::System.new("You are helpful."),
          Riffer::Messages::User.new("Hello"),
          Riffer::Messages::Assistant.new("Hi there!"),
        ]
        session = Riffer::Agent::Session.new(messages: history)

        agent = Riffer::Agent.from_h(dict, context: nil, session: session)

        expect(agent.session).must_be_same_as session
        expect(agent.session.messages.map(&:content)).must_equal ["You are helpful.", "Hello", "Hi there!"]
      end

      it "forwards the session through from_json too" do
        json = build_agent_class.new.to_json
        history = [Riffer::Messages::System.new("You are helpful."), Riffer::Messages::User.new("Resume me")]
        session = Riffer::Agent::Session.new(messages: history)

        agent = Riffer::Agent.from_json(json, context: nil, session: session)

        expect(agent.session.messages.last.content).must_equal "Resume me"
      end

      it "does not re-inject the dict's instructions into a provided session" do
        dict = build_agent_class.new.to_h
        session = Riffer::Agent::Session.new(messages: [Riffer::Messages::User.new("No system message here")])

        agent = Riffer::Agent.from_h(dict, context: nil, session: session)

        expect(agent.session.messages.map(&:role)).must_equal [:user]
      end
    end

    it "raises VersionError on an unsupported schema_version" do
      dict = build_agent_class.new.to_h.merge(schema_version: 999)

      expect { Riffer::Agent.from_h(dict, context: nil) }.must_raise Riffer::Agent::Serializer::VersionError
    end

    it "raises a Riffer::ArgumentError subclass for VersionError" do
      expect(Riffer::Agent::Serializer::VersionError.ancestors).must_include Riffer::ArgumentError
    end
  end

  describe "JSON helpers" do
    it "round-trips through to_json / from_json without manual parsing" do
      json = build_agent_class { uses_tools [SerializerWeatherTool] }.new.to_json
      agent = Riffer::Agent.from_json(json, context: nil)

      expect(json).must_be_instance_of String
      expect(agent.config.identifier).must_equal "support"
      expect(agent.tools.map(&:name)).must_equal ["serializer_weather_tool"]
    end

    it "reconstructs the model string from the resolved provider and model name" do
      klass = Class.new(Riffer::Agent) do
        identifier "dyn"
        model -> { "mock/riffer-1" }
      end

      expect(klass.new.to_json).must_match(%r{"model":"mock/riffer-1"})
    end
  end

  describe "tool hydration" do
    describe "default shell resolver" do
      it "synthesizes shells that pass validate_as_tool!" do
        dict = build_agent_class { uses_tools [SerializerWeatherTool] }.new.to_h
        shell = Riffer::Agent.from_h(dict, context: nil).tools.first

        expect(shell.validate_as_tool!).must_equal true
        expect(shell.name).must_equal "serializer_weather_tool"
      end

      it "advertises the descriptor's parameters schema" do
        dict = build_agent_class { uses_tools [SerializerWeatherTool] }.new.to_h
        shell = Riffer::Agent.from_h(dict, context: nil).tools.first

        expect(shell.parameters_schema[:properties]["city"][:type]).must_equal "string"
      end

      it "raises a clear error if a shell's #call is invoked in-process" do
        dict = build_agent_class { uses_tools [SerializerWeatherTool] }.new.to_h
        shell = Riffer::Agent.from_h(dict, context: nil).tools.first

        error = expect { shell.new.call(context: nil, city: "NYC") }.must_raise Riffer::Error
        expect(error.message).must_match(/remote Riffer::Tools::Runtime/)
      end

      it "reaches a stable fixed point after the first rebuild" do
        dict = build_agent_class { uses_tools [SerializerWeatherTool] }.new.to_h
        once = Riffer::Agent.from_h(dict, context: nil).to_h
        twice = Riffer::Agent.from_h(once, context: nil).to_h

        expect(twice).must_equal once
      end
    end

    describe "custom resolver (registry lookup)" do
      it "rebuilds the real tool class and runs it in-process" do
        dict = build_agent_class { uses_tools [SerializerWeatherTool] }.new.to_h
        registry = { "serializer_weather_tool" => SerializerWeatherTool }
        agent = Riffer::Agent.from_h(dict, context: nil, tool_resolver: ->(d) { registry.fetch(d[:name]) })

        expect(agent.tools.first).must_equal SerializerWeatherTool
        expect(agent.tool_runtime).must_be_instance_of Riffer::Tools::Runtime::Inline
      end

      it "is byte-stable with the origin dict" do
        dict = build_agent_class { uses_tools [SerializerWeatherTool] }.new.to_h
        registry = { "serializer_weather_tool" => SerializerWeatherTool }
        rebuilt = Riffer::Agent.from_h(dict, context: nil, tool_resolver: ->(d) { registry.fetch(d[:name]) })

        expect(rebuilt.to_h).must_equal dict
      end
    end

    describe "injected tool_runtime" do
      it "uses the injected runtime for shells" do
        runtime = Riffer::Tools::Runtime::Inline.new
        dict = build_agent_class { uses_tools [SerializerWeatherTool] }.new.to_h
        agent = Riffer::Agent.from_h(dict, context: nil, tool_runtime: runtime)

        expect(agent.tool_runtime).must_be_same_as runtime
      end
    end
  end
end
