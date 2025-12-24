# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Base do
  let(:provider) { Riffer::Providers::Base.new }

  describe ".identifier" do
    it "can be set and retrieved" do
      test_class = Class.new(Riffer::Providers::Base) do
        identifier "test_provider"
      end
      expect(test_class.identifier).must_equal "test_provider"
    end

    it "registers provider when identifier is set" do
      test_class = Class.new(Riffer::Providers::Base) do
        identifier "custom_provider"
      end
      expect(Riffer::Providers::Base.find_provider("custom_provider")).must_equal test_class
    end
  end

  describe ".find_provider" do
    it "returns registered provider class" do
      expect(Riffer::Providers::Base.find_provider("openai")).must_equal Riffer::Providers::OpenAI
    end

    it "returns registered test provider class" do
      expect(Riffer::Providers::Base.find_provider("test")).must_equal Riffer::Providers::Test
    end

    it "raises error when provider not found" do
      error = expect do
        Riffer::Providers::Base.find_provider("non_existent")
      end.must_raise(Riffer::Providers::InvalidInputError)
      expect(error.message).must_match(/Provider not found for identifier: non_existent/)
    end
  end

  describe "#generate_text" do
    it "raises NotImplementedError when perform_generate_text not implemented" do
      error = expect { provider.generate_text(prompt: "Hello") }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #perform_generate_text"
    end

    it "raises InvalidInputError when no prompt or messages provided" do
      error = expect { provider.generate_text }.must_raise(Riffer::Providers::InvalidInputError)
      expect(error.message).must_equal "prompt is required when messages is not provided"
    end

    it "raises InvalidInputError when both prompt and messages provided" do
      error = expect do
        provider.generate_text(prompt: "Hello", messages: [{role: "user", content: "Hi"}])
      end.must_raise(Riffer::Providers::InvalidInputError)
      expect(error.message).must_equal "cannot provide both prompt and messages"
    end

    it "raises InvalidInputError when both system and messages provided" do
      error = expect do
        provider.generate_text(system: "You are helpful", messages: [{role: "user", content: "Hi"}])
      end.must_raise(Riffer::Providers::InvalidInputError)
      expect(error.message).must_equal "cannot provide both system and messages"
    end

    it "raises InvalidInputError when messages has no user message" do
      error = expect do
        provider.generate_text(messages: [{role: "system", content: "You are helpful"}])
      end.must_raise(Riffer::Providers::InvalidInputError)
      expect(error.message).must_equal "messages must include at least one user message"
    end
  end

  describe "#stream_text" do
    it "raises NotImplementedError when perform_stream_text not implemented" do
      error = expect { provider.stream_text(prompt: "Hello") }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #perform_stream_text"
    end
  end

  describe "#normalize_messages" do
    it "converts prompt to User message" do
      result = provider.send(:normalize_messages, prompt: "Hello", system: nil, messages: nil)
      expect(result.all? { |msg| msg.is_a?(Riffer::Messages::Base) }).must_equal true
    end

    it "converts system and prompt to System and User messages" do
      result = provider.send(:normalize_messages, prompt: "Hello", system: "Be helpful", messages: nil)
      expect(result.all? { |msg| msg.is_a?(Riffer::Messages::Base) }).must_equal true
    end

    describe "with hash messages" do
      let(:messages) do
        [
          {role: "user", content: "Hello"},
          {role: "assistant", content: "Hi there"}
        ]
      end

      it "converts hash messages to message objects" do
        result = provider.send(:normalize_messages, prompt: nil, system: nil, messages: messages)
        expect(result.all? { |msg| msg.is_a?(Riffer::Messages::Base) }).must_equal true
      end
    end

    describe "with message objects" do
      let(:messages) do
        [
          Riffer::Messages::User.new("Hello"),
          Riffer::Messages::Assistant.new("Hi there")
        ]
      end

      it "preserves message objects when provided" do
        result = provider.send(:normalize_messages, prompt: nil, system: nil, messages: messages)
        expect(result).must_equal messages
      end
    end
  end

  describe "#convert_to_message_object" do
    it "raises InvalidInputError when message is not a Hash or Message object" do
      error = expect do
        provider.send(:convert_to_message_object, "invalid")
      end.must_raise(Riffer::Providers::InvalidInputError)
      expect(error.message).must_equal "Message must be a Hash or Message object, got String"
    end

    it "raises InvalidInputError when message has unknown role" do
      error = expect do
        provider.send(:convert_to_message_object, {role: "unknown", content: "test"})
      end.must_raise(Riffer::Providers::InvalidInputError)
      expect(error.message).must_equal "Unknown message role: unknown"
    end

    it "converts user hash to User message" do
      result = provider.send(:convert_to_message_object, {role: "user", content: "Hello"})
      expect(result).must_be_instance_of Riffer::Messages::User
    end

    it "converts assistant hash to Assistant message" do
      result = provider.send(:convert_to_message_object, {role: "assistant", content: "Hi"})
      expect(result).must_be_instance_of Riffer::Messages::Assistant
    end

    it "converts system hash to System message" do
      result = provider.send(:convert_to_message_object, {role: "system", content: "Be helpful"})
      expect(result).must_be_instance_of Riffer::Messages::System
    end

    describe "with tool message hash" do
      let(:tool_message) do
        {
          role: "tool",
          content: "Result",
          tool_call_id: "123",
          name: "search"
        }
      end

      it "converts tool hash to Tool message" do
        result = provider.send(:convert_to_message_object, tool_message)
        expect(result).must_be_instance_of Riffer::Messages::Tool
      end
    end

    it "preserves message objects" do
      msg = Riffer::Messages::User.new("Hello")
      result = provider.send(:convert_to_message_object, msg)
      expect(result).must_equal msg
    end

    describe "with assistant message with tool_calls" do
      let(:assistant_message) do
        {
          role: "assistant",
          content: "Let me search",
          tool_calls: [{id: "1", name: "search"}]
        }
      end

      it "preserves tool_calls in assistant messages" do
        result = provider.send(:convert_to_message_object, assistant_message)
        expect(result.tool_calls).must_equal [{id: "1", name: "search"}]
      end
    end
  end

  describe "#has_user_message?" do
    it "returns true for User message object" do
      messages = [Riffer::Messages::User.new("Hello")]
      expect(provider.send(:has_user_message?, messages)).must_equal true
    end

    it "returns true for user hash message" do
      messages = [{role: "user", content: "Hello"}]
      expect(provider.send(:has_user_message?, messages)).must_equal true
    end

    it "returns false when no user messages present" do
      messages = [{role: "system", content: "Be helpful"}]
      expect(provider.send(:has_user_message?, messages)).must_equal false
    end
  end
end
