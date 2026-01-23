# frozen_string_literal: true

require "test_helper"

describe Riffer::Agent do
  let(:agent_class) do
    Class.new(Riffer::Agent) do
      identifier "test-agent"
      model "test/riffer-1"
      instructions "You are a helpful assistant."
    end
  end

  describe ".identifier" do
    it "sets the identifier" do
      expect(agent_class.identifier).must_equal "test-agent"
    end

    it "converts non-string identifier to string" do
      agent_class.identifier(:test_agent)
      expect(agent_class.identifier).must_equal "test_agent"
    end

    it "defaults to snake_case class name when not set" do
      expect(Riffer::Agent.identifier).must_equal "riffer/agent"
    end
  end

  describe ".model" do
    it "sets the model" do
      expect(agent_class.model).must_equal "test/riffer-1"
    end

    it "raises error when model is not a string" do
      error = expect { agent_class.model(123) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/model must be a String/)
    end

    it "raises error when model is an empty string" do
      error = expect { agent_class.model("   ") }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/model cannot be empty/)
    end
  end

  describe ".instructions" do
    it "sets the instructions" do
      expect(agent_class.instructions).must_equal "You are a helpful assistant."
    end

    it "raises error when instructions is not a string" do
      error = expect { agent_class.instructions(123) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/instructions must be a String/)
    end

    it "raises error when instructions is an empty string" do
      error = expect { agent_class.instructions("   ") }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/instructions cannot be empty/)
    end
  end

  describe ".provider_options" do
    it "returns empty hash when not set" do
      expect(agent_class.provider_options).must_equal({})
    end

    it "sets the provider options" do
      agent_class.provider_options(api_key: "test-key")
      expect(agent_class.provider_options).must_equal({api_key: "test-key"})
    end
  end

  describe ".model_options" do
    it "returns empty hash when not set" do
      expect(agent_class.model_options).must_equal({})
    end

    it "sets the model options" do
      agent_class.model_options(reasoning: "medium")
      expect(agent_class.model_options).must_equal({reasoning: "medium"})
    end
  end

  describe "#initialize" do
    it "initializes with empty messages" do
      agent = agent_class.new
      expect(agent.messages).must_equal []
    end

    describe "with invalid model format" do
      let(:invalid_agent_class) do
        Class.new(Riffer::Agent) do
          model "invalid-format"
        end
      end

      it "raises error for missing provider or model name" do
        error = expect { invalid_agent_class.new }.must_raise(Riffer::ArgumentError)
        expect(error.message).must_match(/Invalid model string: invalid-format/)
      end
    end
  end

  describe "#generate" do
    describe "with model_options" do
      let(:options_agent_class) do
        Class.new(Riffer::Agent) do
          identifier "options-agent"
          model "test/riffer-1"
          instructions "You are a helpful assistant."
          model_options reasoning: "medium", temperature: 0.7
        end
      end

      it "passes model_options to provider" do
        agent = options_agent_class.new
        provider = agent.send(:provider_instance)
        agent.generate("Hello")
        expect(provider.calls.last[:reasoning]).must_equal "medium"
      end

      it "passes all model_options to provider" do
        agent = options_agent_class.new
        provider = agent.send(:provider_instance)
        agent.generate("Hello")
        expect(provider.calls.last[:temperature]).must_equal 0.7
      end
    end

    describe "with test provider" do
      it "returns a text response" do
        agent = agent_class.new
        result = agent.generate("What is the weather?")
        expect(result).must_be_instance_of String
      end

      it "adds system message to messages when instructions are provided" do
        agent = agent_class.new
        agent.generate("Hello")
        system_message = agent.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message).wont_be_nil
      end

      it "adds user message to messages" do
        agent = agent_class.new
        agent.generate("Hello")
        user_message = agent.messages.find { |msg| msg.is_a?(Riffer::Messages::User) }
        expect(user_message).wont_be_nil
      end

      it "adds assistant message to messages" do
        agent = agent_class.new
        agent.generate("Hello")
        assistant_message = agent.messages.find { |msg| msg.is_a?(Riffer::Messages::Assistant) }
        expect(assistant_message).wont_be_nil
      end

      it "returns the content of the final assistant message" do
        agent = agent_class.new
        result = agent.generate("Hello")
        expect(result).must_be_instance_of String
      end
    end

    describe "with an array of messages" do
      it "accepts an array of messages" do
        agent = agent_class.new
        messages = [
          Riffer::Messages::User.new("Hello"),
          Riffer::Messages::Assistant.new("Hi there!"),
          Riffer::Messages::User.new("How are you?")
        ]
        result = agent.generate(messages)
        expect(result).must_be_instance_of String
      end

      it "adds system message before the provided messages when instructions are present" do
        agent = agent_class.new
        messages = [Riffer::Messages::User.new("Hello")]
        agent.generate(messages)
        expect(agent.messages.first).must_be_instance_of Riffer::Messages::System
      end

      it "preserves message order with system message first" do
        agent = agent_class.new
        messages = [Riffer::Messages::User.new("Hello")]
        agent.generate(messages)
        expect(agent.messages[1]).must_be_instance_of Riffer::Messages::User
      end

      it "preserves all provided messages" do
        agent = agent_class.new
        messages = [
          Riffer::Messages::User.new("First message"),
          Riffer::Messages::Assistant.new("Response"),
          Riffer::Messages::User.new("Second message")
        ]
        agent.generate(messages)
        user_messages = agent.messages.select { |msg| msg.is_a?(Riffer::Messages::User) }
        expect(user_messages.length).must_be :>=, 2
      end
    end

    describe "with an array of hashes" do
      it "accepts an array of hashes and converts them to messages" do
        agent = agent_class.new
        messages = [
          {role: "user", content: "Hello"},
          {role: "assistant", content: "Hi there!"},
          {role: "user", content: "How are you?"}
        ]
        result = agent.generate(messages)
        expect(result).must_be_instance_of String
      end

      it "supports mixed hash and message objects" do
        agent = agent_class.new
        messages = [
          {role: "user", content: "First"},
          Riffer::Messages::Assistant.new("Second"),
          {role: "user", content: "Third"}
        ]
        agent.generate(messages)
        user_messages = agent.messages.select { |msg| msg.is_a?(Riffer::Messages::User) }
        expect(user_messages.length).must_be :>=, 2
      end
    end

    describe "without instructions" do
      let(:no_instructions_agent_class) do
        Class.new(Riffer::Agent) do
          model "test/gpt-4o"
        end
      end

      it "does not add system message" do
        agent = no_instructions_agent_class.new
        agent.generate("Hello")
        system_message = agent.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message).must_be_nil
      end
    end

    describe "with invalid provider" do
      it "raises error when provider is not found" do
        invalid_agent_class = Class.new(Riffer::Agent) do
          model "nonexistent/gpt-4"
        end

        agent = invalid_agent_class.new
        error = expect { agent.generate("Hello") }.must_raise(Riffer::ArgumentError)
        expect(error.message).must_match(/Provider not found: nonexistent/)
      end
    end
  end

  describe "#stream" do
    describe "with model_options" do
      let(:options_agent_class) do
        Class.new(Riffer::Agent) do
          identifier "options-stream-agent"
          model "test/riffer-1"
          instructions "You are a helpful assistant."
          model_options reasoning: "high", temperature: 0.5
        end
      end

      it "passes model_options to provider" do
        agent = options_agent_class.new
        provider = agent.send(:provider_instance)
        agent.stream("Hello").each { |_| }
        expect(provider.calls.last[:reasoning]).must_equal "high"
      end

      it "passes all model_options to provider" do
        agent = options_agent_class.new
        provider = agent.send(:provider_instance)
        agent.stream("Hello").each { |_| }
        expect(provider.calls.last[:temperature]).must_equal 0.5
      end
    end

    describe "with test provider" do
      it "returns an enumerator" do
        agent = agent_class.new
        result = agent.stream("What is the weather?")
        expect(result).must_be_instance_of Enumerator
      end

      it "yields stream events" do
        agent = agent_class.new
        chunks = []
        agent.stream("Hello").each do |chunk|
          chunks << chunk
        end
        expect(chunks).wont_be_empty
      end

      it "yields TextDelta events" do
        agent = agent_class.new
        events = agent.stream("Hello").to_a
        text_deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
        expect(text_deltas).wont_be_empty
      end

      it "yields a TextDone event" do
        agent = agent_class.new
        events = agent.stream("Hello").to_a
        text_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
        expect(text_done).wont_be_nil
      end

      it "adds system message to messages when instructions are provided" do
        agent = agent_class.new
        agent.stream("Hello").each { |_| }
        system_message = agent.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message).wont_be_nil
      end

      it "adds user message to messages" do
        agent = agent_class.new
        agent.stream("Hello").each { |_| }
        user_message = agent.messages.find { |msg| msg.is_a?(Riffer::Messages::User) }
        expect(user_message).wont_be_nil
      end

      it "adds assistant message to messages" do
        agent = agent_class.new
        agent.stream("Hello").each { |_| }
        assistant_message = agent.messages.find { |msg| msg.is_a?(Riffer::Messages::Assistant) }
        expect(assistant_message).wont_be_nil
      end

      it "accumulates content from TextDelta events" do
        agent = agent_class.new
        agent.stream("Hello").each { |_| }
        assistant_message = agent.messages.find { |msg| msg.is_a?(Riffer::Messages::Assistant) }
        expect(assistant_message.content).wont_be_empty
      end
    end

    describe "with an array of messages" do
      it "accepts an array of messages" do
        agent = agent_class.new
        messages = [
          Riffer::Messages::User.new("Hello"),
          Riffer::Messages::Assistant.new("Hi there!"),
          Riffer::Messages::User.new("How are you?")
        ]
        result = agent.stream(messages)
        expect(result).must_be_instance_of Enumerator
      end

      it "adds system message before the provided messages when instructions are present" do
        agent = agent_class.new
        messages = [Riffer::Messages::User.new("Hello")]
        agent.stream(messages).each { |_| }
        expect(agent.messages.first).must_be_instance_of Riffer::Messages::System
      end

      it "preserves message order with system message first" do
        agent = agent_class.new
        messages = [Riffer::Messages::User.new("Hello")]
        agent.stream(messages).each { |_| }
        expect(agent.messages[1]).must_be_instance_of Riffer::Messages::User
      end
    end

    describe "with an array of hashes" do
      it "accepts an array of hashes and converts them to messages" do
        agent = agent_class.new
        messages = [
          {role: "user", content: "Hello"},
          {role: "assistant", content: "Hi there!"},
          {role: "user", content: "How are you?"}
        ]
        result = agent.stream(messages)
        expect(result).must_be_instance_of Enumerator
      end
    end

    describe "without instructions" do
      let(:no_instructions_agent_class) do
        Class.new(Riffer::Agent) do
          model "test/gpt-4o"
        end
      end

      it "does not add system message" do
        agent = no_instructions_agent_class.new
        agent.stream("Hello").each { |_| }
        system_message = agent.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message).must_be_nil
      end
    end

    describe "with invalid provider" do
      it "raises error when provider is not found" do
        invalid_agent_class = Class.new(Riffer::Agent) do
          model "nonexistent/gpt-4"
        end

        agent = invalid_agent_class.new
        error = expect { agent.stream("Hello").each { |_| } }.must_raise(Riffer::ArgumentError)
        expect(error.message).must_match(/Provider not found: nonexistent/)
      end
    end
  end

  describe "instructions validation" do
    it "raises error when instructions is empty string" do
      error = expect do
        Class.new(Riffer::Agent) do
          model "test/riffer-1"
          instructions "   "
        end
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/instructions cannot be empty/)
    end
  end

  describe ".find" do
    before do
      @test_agent_class = Class.new(Riffer::Agent) do
        identifier "findable-agent"
        model "test/riffer-1"
      end
    end

    it "returns the agent class with matching identifier" do
      found_agent = Riffer::Agent.find("findable-agent")
      expect(found_agent).must_equal @test_agent_class
    end

    it "returns nil when identifier is not found" do
      found_agent = Riffer::Agent.find("nonexistent-agent")
      expect(found_agent).must_be_nil
    end
  end

  describe ".all" do
    before do
      @agent1 = Class.new(Riffer::Agent) do
        identifier "all-test-agent-1"
        model "test/riffer-1"
      end

      @agent2 = Class.new(Riffer::Agent) do
        identifier "all-test-agent-2"
        model "test/riffer-2"
      end
    end

    it "returns an array of agent classes" do
      result = Riffer::Agent.all
      expect(result).must_be_instance_of Array
    end

    it "includes agent 1" do
      all_agents = Riffer::Agent.all
      expect(all_agents).must_include @agent1
    end

    it "includes agent 2" do
      all_agents = Riffer::Agent.all
      expect(all_agents).must_include @agent2
    end
  end

  describe ".uses_tools" do
    let(:weather_tool_class) do
      Class.new(Riffer::Tool) do
        description "Gets the weather"

        params do
          required :city, String
        end

        def call(context:, city:)
          "Weather in #{city}: 20 degrees"
        end
      end
    end

    let(:agent_with_tools_class) do
      tool_class = weather_tool_class
      Class.new(Riffer::Agent) do
        model "test/riffer-1"
        uses_tools [tool_class]
      end
    end

    it "returns nil when not set" do
      expect(agent_class.uses_tools).must_be_nil
    end

    it "sets the tools array" do
      expect(agent_with_tools_class.uses_tools).must_equal [weather_tool_class]
    end

    it "accepts a lambda" do
      tool_class = weather_tool_class
      agent = Class.new(Riffer::Agent) do
        model "test/riffer-1"
        uses_tools -> { [tool_class] }
      end
      expect(agent.uses_tools).must_be_instance_of Proc
    end
  end

  describe "tool calling" do
    let(:weather_tool_class) do
      Class.new(Riffer::Tool) do
        description "Gets the weather"

        params do
          required :city, String
        end

        def call(context:, city:)
          "Weather in #{city}: 20 degrees"
        end
      end
    end

    let(:context_tool_class) do
      Class.new(Riffer::Tool) do
        description "Gets user info"

        params do
          required :field, String
        end

        def call(context:, field:)
          context[field.to_sym] || "unknown"
        end
      end
    end

    describe "#generate with tools" do
      it "adds tool message after executing tool call" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather in Toronto is nice!")

        agent.generate("What's the weather in Toronto?")

        tool_messages = agent.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.length).must_equal 1
      end

      it "includes tool result in tool message content" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather in Toronto is nice!")

        agent.generate("What's the weather in Toronto?")

        tool_messages = agent.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.first.content).must_equal "Weather in Toronto: 20 degrees"
      end

      it "returns final response after tool execution" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather in Toronto is nice!")

        result = agent.generate("What's the weather in Toronto?")

        expect(result).must_equal "The weather in Toronto is nice!"
      end

      it "passes tool_context to tools" do
        tool_class = context_tool_class
        tool_class.identifier("context_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "context_tool", arguments: '{"field":"user_name"}'}
        ])
        provider.stub_response("Your name is Alice!")

        agent.generate("Get my name", tool_context: {user_name: "Alice"})

        tool_messages = agent.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.first.content).must_equal "Alice"
      end

      it "returns error message for unknown tool" do
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools []
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "nonexistent_tool", arguments: "{}"}
        ])
        provider.stub_response("I couldn't find that tool.")

        agent.generate("Call nonexistent tool")

        tool_messages = agent.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.first.content).must_match(/Unknown tool/)
      end

      it "sets error attributes for unknown tool" do
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools []
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "nonexistent_tool", arguments: "{}"}
        ])
        provider.stub_response("I couldn't find that tool.")

        agent.generate("Call nonexistent tool")

        tool_message = agent.messages.find { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_message.error?).must_equal true
        expect(tool_message.error).must_equal "Unknown tool 'nonexistent_tool'"
        expect(tool_message.error_type).must_equal :unknown_tool
      end

      it "handles validation errors gracefully" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: "{}"}
        ])
        provider.stub_response("Sorry, I need a city.")

        agent.generate("What's the weather?")

        tool_messages = agent.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.first.content).must_match(/Validation error/)
      end

      it "sets error attributes for validation errors" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: "{}"}
        ])
        provider.stub_response("Sorry, I need a city.")

        agent.generate("What's the weather?")

        tool_message = agent.messages.find { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_message.error?).must_equal true
        expect(tool_message.error_type).must_equal :validation_error
      end

      it "does not set error attributes for successful tool calls" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather in Toronto is nice!")

        agent.generate("What's the weather in Toronto?")

        tool_message = agent.messages.find { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_message.error?).must_equal false
        expect(tool_message.error).must_be_nil
        expect(tool_message.error_type).must_be_nil
      end

      it "passes tools to provider" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        agent.generate("Hello")

        expect(provider.calls.last[:tools]).wont_be_nil
      end

      it "passes correct number of tools to provider" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        agent.generate("Hello")

        expect(provider.calls.last[:tools].length).must_equal 1
      end
    end

    describe "#stream with tools" do
      it "yields tool call events" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather is nice!")

        events = agent.stream("What's the weather?").to_a

        tool_call_done_events = events.select { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
        expect(tool_call_done_events).wont_be_empty
      end

      it "adds tool messages during streaming" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather is nice!")

        agent.stream("What's the weather?").each { |_| }

        tool_messages = agent.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.length).must_equal 1
      end

      it "passes tool_context in streaming mode" do
        tool_class = context_tool_class
        tool_class.identifier("context_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "context_tool", arguments: '{"field":"user_id"}'}
        ])
        provider.stub_response("Your ID is 12345!")

        agent.stream("Get my id", tool_context: {user_id: "12345"}).each { |_| }

        tool_messages = agent.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.first.content).must_equal "12345"
      end
    end

    describe "with lambda-based tools" do
      it "evaluates lambda at resolution time" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        call_count = 0

        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools -> {
            call_count += 1
            [tool_class]
          }
        end

        agent = agent_class.new
        agent.generate("Hello")

        expect(call_count).must_be :>, 0
      end

      it "passes tool_context to lambda when it accepts a parameter" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        received_context = nil

        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools ->(context) {
            received_context = context
            [tool_class]
          }
        end

        agent = agent_class.new
        context = {user_id: 123, admin: true}
        agent.generate("Hello", tool_context: context)

        expect(received_context).must_equal context
      end

      it "allows conditional tool resolution based on context" do
        admin_tool_class = Class.new(Riffer::Tool) do
          description "Admin only tool"
          params {}
          def call(context:)
            "admin action"
          end
        end
        admin_tool_class.identifier("admin_tool")

        basic_tool_class = weather_tool_class
        basic_tool_class.identifier("weather_tool")

        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools ->(context) {
            tools = [basic_tool_class]
            tools << admin_tool_class if context&.dig(:admin)
            tools
          }
        end

        admin_agent = agent_class.new
        provider = admin_agent.send(:provider_instance)
        provider.stub_response("Done")
        admin_agent.generate("Hello", tool_context: {admin: true})
        admin_tools = provider.calls.last[:tools]

        regular_agent = agent_class.new
        provider2 = regular_agent.send(:provider_instance)
        provider2.stub_response("Done")
        regular_agent.generate("Hello", tool_context: {admin: false})
        regular_tools = provider2.calls.last[:tools]

        expect(admin_tools.length).must_equal 2
        expect(regular_tools.length).must_equal 1
      end

      it "re-evaluates lambda for each generate call" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        contexts_received = []

        agent_class = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools ->(context) {
            contexts_received << context
            [tool_class]
          }
        end

        agent = agent_class.new
        agent.generate("Hello", tool_context: {call: 1})
        agent.generate("Hello again", tool_context: {call: 2})

        expect(contexts_received.length).must_equal 2
        expect(contexts_received[0]).must_equal({call: 1})
        expect(contexts_received[1]).must_equal({call: 2})
      end
    end
  end

  describe "#on_message" do
    it "raises error without block" do
      agent = agent_class.new
      error = expect { agent.on_message }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/on_message requires a block/)
    end

    it "returns self for chaining" do
      agent = agent_class.new
      result = agent.on_message { |_| }
      expect(result).must_equal agent
    end

    describe "with multiple callbacks" do
      let(:callbacks_called) { [] }
      let(:agent) do
        a = agent_class.new
        a.on_message { |_| callbacks_called << 1 }
        a.on_message { |_| callbacks_called << 2 }
        a.generate("Hello")
        a
      end

      it "calls first callback" do
        agent
        expect(callbacks_called).must_include 1
      end

      it "calls second callback" do
        agent
        expect(callbacks_called).must_include 2
      end
    end
  end

  describe "message emit with #generate" do
    describe "on simple generate" do
      let(:emitted) { [] }
      let(:agent) do
        a = agent_class.new
        a.on_message { |msg| emitted << msg }
        a.generate("Hello")
        a
      end

      it "emits one message" do
        agent
        expect(emitted.length).must_equal 1
      end

      it "emits an assistant message" do
        agent
        expect(emitted.first).must_be_instance_of Riffer::Messages::Assistant
      end
    end

    describe "during tool use" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          description "Gets the weather"
          params do
            required :city, String
          end
          def call(context:, city:)
            "Weather in #{city}: 20 degrees"
          end
        end.tap { |t| t.identifier("emit_weather_tool") }
      end

      let(:emitted) { [] }
      let(:agent) do
        tc = tool_class
        agent_with_tools = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tc]
        end

        a = agent_with_tools.new
        provider = a.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "emit_weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather is nice!")

        a.on_message { |msg| emitted << msg }
        a.generate("What's the weather?")
        a
      end

      it "emits three messages" do
        agent
        expect(emitted.length).must_equal 3
      end

      it "emits assistant with tool_calls first" do
        agent
        expect(emitted[0]).must_be_instance_of Riffer::Messages::Assistant
      end

      it "includes tool_calls in first assistant message" do
        agent
        expect(emitted[0].tool_calls).wont_be_empty
      end

      it "emits tool message second" do
        agent
        expect(emitted[1]).must_be_instance_of Riffer::Messages::Tool
      end

      it "emits final assistant message third" do
        agent
        expect(emitted[2]).must_be_instance_of Riffer::Messages::Assistant
      end
    end

    describe "when tool fails" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          description "A failing tool"
          params do
            required :value, String
          end
          def call(context:, value:)
            raise "Something went wrong"
          end
        end.tap { |t| t.identifier("failing_tool") }
      end

      let(:emitted) { [] }
      let(:tool_message) do
        tc = tool_class
        agent_with_tools = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tc]
        end

        agent = agent_with_tools.new
        provider = agent.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "failing_tool", arguments: '{"value":"test"}'}
        ])
        provider.stub_response("Tool failed.")

        agent.on_message { |msg| emitted << msg }
        agent.generate("Call tool")

        emitted.find { |m| m.is_a?(Riffer::Messages::Tool) }
      end

      it "emits tool message with error flag" do
        expect(tool_message.error?).must_equal true
      end

      it "emits tool message with execution_error type" do
        expect(tool_message.error_type).must_equal :execution_error
      end
    end
  end

  describe "message emit with #stream" do
    describe "on simple stream" do
      let(:emitted) { [] }
      let(:agent) do
        a = agent_class.new
        a.on_message { |msg| emitted << msg }
        a.stream("Hello").each { |_| }
        a
      end

      it "emits one message" do
        agent
        expect(emitted.length).must_equal 1
      end

      it "emits an assistant message" do
        agent
        expect(emitted.first).must_be_instance_of Riffer::Messages::Assistant
      end
    end

    describe "during tool calling loop" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          description "Gets the weather"
          params do
            required :city, String
          end
          def call(context:, city:)
            "Weather in #{city}: 20 degrees"
          end
        end.tap { |t| t.identifier("stream_emit_weather_tool") }
      end

      let(:emitted) { [] }
      let(:agent) do
        tc = tool_class
        agent_with_tools = Class.new(Riffer::Agent) do
          model "test/riffer-1"
          uses_tools [tc]
        end

        a = agent_with_tools.new
        provider = a.send(:provider_instance)
        provider.stub_response("", tool_calls: [
          {name: "stream_emit_weather_tool", arguments: '{"city":"Tokyo"}'}
        ])
        provider.stub_response("The weather is nice!")

        a.on_message { |msg| emitted << msg }
        a.stream("What's the weather?").each { |_| }
        a
      end

      it "emits three messages" do
        agent
        expect(emitted.length).must_equal 3
      end

      it "emits assistant message first" do
        agent
        expect(emitted[0]).must_be_instance_of Riffer::Messages::Assistant
      end

      it "emits tool message second" do
        agent
        expect(emitted[1]).must_be_instance_of Riffer::Messages::Tool
      end

      it "emits final assistant message third" do
        agent
        expect(emitted[2]).must_be_instance_of Riffer::Messages::Assistant
      end
    end
  end
end
