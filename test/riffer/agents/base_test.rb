# frozen_string_literal: true

require "test_helper"

describe Riffer::Agents::Base do
  let(:agent_class) do
    Class.new(Riffer::Agents::Base) do
      model "test/riffer-1"
      instructions "You are a helpful assistant."
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
end
