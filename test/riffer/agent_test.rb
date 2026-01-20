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
end
