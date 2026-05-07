# frozen_string_literal: true

require "test_helper"

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

    it "omits slots that are deferred or carried in messages" do
      klass = Class.new(Riffer::Agent) do
        identifier "x"
        model "mock/riffer-1"
        instructions "You are helpful."
      end

      config = klass.to_config
      [:instructions, :skills, :tools, :tool_runtime, :guardrails].each do |slot|
        refute config.key?(slot), "#{slot} should not be in the config"
      end
    end

    it "accepts string-keyed config hashes from JSON.parse" do
      sender = Class.new(Riffer::Agent) do
        identifier "string-keys"
        model "mock/riffer-1"
        provider_options(api_key: "k")
      end

      json = JSON.dump(sender.to_config)
      restored = Riffer::Agent.from_config(JSON.parse(json)) # no symbolize_names

      expect(restored.identifier).must_equal "string-keys"
      expect(restored.provider_options).must_equal({api_key: "k"})
    end

    it "end-to-end: serialize sender, ship messages, run on receiver" do
      sender_class = Class.new(Riffer::Agent) do
        identifier "e2e"
        model "mock/riffer-1"
        instructions ->(ctx) { "You are helping #{ctx[:name]}." }
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
