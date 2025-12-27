# frozen_string_literal: true

require "test_helper"

describe Riffer::Agents::Base do
  let(:agent_class) do
    Class.new(Riffer::Agents::Base) do
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
  end

  describe ".model" do
    it "sets the model" do
      expect(agent_class.model).must_equal "test/riffer-1"
    end

    it "raises error when model is not a string" do
      error = expect { agent_class.model(123) }.must_raise(ArgumentError)
      expect(error.message).must_match(/model must be a String/)
    end

    it "raises error when model is an empty string" do
      error = expect { agent_class.model("   ") }.must_raise(ArgumentError)
      expect(error.message).must_match(/model cannot be empty/)
    end
  end

  describe ".instructions" do
    it "sets the instructions" do
      expect(agent_class.instructions).must_equal "You are a helpful assistant."
    end

    it "raises error when instructions is not a string" do
      error = expect { agent_class.instructions(123) }.must_raise(ArgumentError)
      expect(error.message).must_match(/instructions must be a String/)
    end

    it "raises error when instructions is an empty string" do
      error = expect { agent_class.instructions("   ") }.must_raise(ArgumentError)
      expect(error.message).must_match(/instructions cannot be empty/)
    end
  end

  describe "#initialize" do
    it "initializes with empty messages" do
      agent = agent_class.new
      expect(agent.messages).must_equal []
    end

    describe "with invalid model format" do
      let(:invalid_agent_class) do
        Class.new(Riffer::Agents::Base) do
          model "invalid-format"
        end
      end

      it "raises error for missing provider or model name" do
        error = expect { invalid_agent_class.new }.must_raise(ArgumentError)
        expect(error.message).must_match(/Invalid model string: invalid-format/)
      end
    end
  end

  describe "#generate" do
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

      it "converts user role hash to User message" do
        agent = agent_class.new
        messages = [{role: "user", content: "Test message"}]
        agent.generate(messages)
        user_message = agent.messages.find { |msg| msg.is_a?(Riffer::Messages::User) }
        expect(user_message).wont_be_nil
        expect(user_message.content).must_equal "Test message"
      end

      it "converts assistant role hash to Assistant message" do
        agent = agent_class.new
        messages = [
          {role: "user", content: "Question"},
          {role: "assistant", content: "Answer"}
        ]
        agent.generate(messages)
        assistant_messages = agent.messages.select { |msg| msg.is_a?(Riffer::Messages::Assistant) }
        expect(assistant_messages.any? { |msg| msg.content == "Answer" }).must_equal true
      end

      it "converts system role hash to System message" do
        no_instructions_agent_class = Class.new(Riffer::Agents::Base) do
          model "test/gpt-4o"
        end
        agent = no_instructions_agent_class.new
        messages = [
          {role: "system", content: "Custom system message"},
          {role: "user", content: "Hello"}
        ]
        agent.generate(messages)
        system_message = agent.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message).wont_be_nil
        expect(system_message.content).must_equal "Custom system message"
      end

      it "handles string keys in hashes" do
        agent = agent_class.new
        messages = [
          {"role" => "user", "content" => "Hello"}
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

      it "raises error for unknown role" do
        agent = agent_class.new
        messages = [{role: "unknown", content: "Test"}]
        error = expect { agent.generate(messages) }.must_raise(Riffer::Messages::InvalidInputError)
        expect(error.message).must_match(/Unknown message role: unknown/)
      end
    end

    describe "without instructions" do
      let(:no_instructions_agent_class) do
        Class.new(Riffer::Agents::Base) do
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
  end

  describe "instructions validation" do
    it "raises error when instructions is empty string" do
      error = expect do
        Class.new(Riffer::Agents::Base) do
          model "test/riffer-1"
          instructions "   "
        end
      end.must_raise(ArgumentError)
      expect(error.message).must_match(/instructions cannot be empty/)
    end
  end

  describe ".find" do
    before do
      @test_agent_class = Class.new(Riffer::Agents::Base) do
        identifier "findable-agent"
        model "test/riffer-1"
      end
    end

    it "returns the agent class with matching identifier" do
      found_agent = Riffer::Agents::Base.find("findable-agent")
      expect(found_agent).must_equal @test_agent_class
    end

    it "returns nil when identifier is not found" do
      found_agent = Riffer::Agents::Base.find("nonexistent-agent")
      expect(found_agent).must_be_nil
    end
  end

  describe ".all" do
    before do
      @agent1 = Class.new(Riffer::Agents::Base) do
        identifier "all-test-agent-1"
        model "test/riffer-1"
      end

      @agent2 = Class.new(Riffer::Agents::Base) do
        identifier "all-test-agent-2"
        model "test/riffer-2"
      end
    end

    it "returns an array of agent classes" do
      result = Riffer::Agents::Base.all
      expect(result).must_be_instance_of Array
    end

    it "includes agent 1" do
      all_agents = Riffer::Agents::Base.all
      expect(all_agents).must_include @agent1
    end

    it "includes agent 2" do
      all_agents = Riffer::Agents::Base.all
      expect(all_agents).must_include @agent2
    end
  end
end
