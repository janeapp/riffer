# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Providers::Base do
  let(:provider) { described_class.new }

  describe ".identifier" do
    it "can be set and retrieved" do
      test_class = Class.new(described_class) do
        identifier "test_provider"
      end

      expect(test_class.identifier).to eq("test_provider")
    end

    it "registers provider when identifier is set" do
      test_class = Class.new(described_class) do
        identifier "custom_provider"
      end

      expect(described_class.find_provider("custom_provider")).to eq(test_class)
    end
  end

  describe ".find_provider" do
    it "returns registered provider class" do
      expect(described_class.find_provider("openai")).to eq(Riffer::Agents::Providers::OpenAI)
    end

    it "returns registered test provider class" do
      expect(described_class.find_provider("test")).to eq(Riffer::Agents::Providers::Test)
    end

    it "raises error when provider not found" do
      expect {
        described_class.find_provider("non_existent")
      }.to raise_error(Riffer::Agents::InvalidInputError, /Provider not found for identifier: non_existent/)
    end
  end

  describe "#generate_text" do
    it "raises NotImplementedError when perform_generate_text not implemented" do
      expect {
        provider.generate_text(prompt: "Hello")
      }.to raise_error(NotImplementedError, "Subclasses must implement #perform_generate_text")
    end

    it "raises InvalidInputError when no prompt or messages provided" do
      expect {
        provider.generate_text
      }.to raise_error(Riffer::Agents::InvalidInputError, "prompt is required when messages is not provided")
    end

    it "raises InvalidInputError when both prompt and messages provided" do
      expect {
        provider.generate_text(prompt: "Hello", messages: [{role: "user", content: "Hi"}])
      }.to raise_error(Riffer::Agents::InvalidInputError, "cannot provide both prompt and messages")
    end

    it "raises InvalidInputError when both system and messages provided" do
      expect {
        provider.generate_text(system: "You are helpful", messages: [{role: "user", content: "Hi"}])
      }.to raise_error(Riffer::Agents::InvalidInputError, "cannot provide both system and messages")
    end

    it "raises InvalidInputError when messages has no user message" do
      expect {
        provider.generate_text(messages: [{role: "system", content: "You are helpful"}])
      }.to raise_error(Riffer::Agents::InvalidInputError, "messages must include at least one user message")
    end
  end

  describe "#stream_text" do
    it "raises NotImplementedError when perform_stream_text not implemented" do
      expect {
        provider.stream_text(prompt: "Hello")
      }.to raise_error(NotImplementedError, "Subclasses must implement #perform_stream_text")
    end
  end

  describe "#normalize_messages" do
    it "converts prompt to User message" do
      result = provider.send(:normalize_messages, prompt: "Hello", system: nil, messages: nil)
      expect(result).to all(be_a(Riffer::Agents::Messages::Base))
    end

    it "converts system and prompt to System and User messages" do
      result = provider.send(:normalize_messages, prompt: "Hello", system: "Be helpful", messages: nil)
      expect(result).to all(be_a(Riffer::Agents::Messages::Base))
    end

    context "with hash messages" do
      let(:messages) do
        [
          {role: "user", content: "Hello"},
          {role: "assistant", content: "Hi there"}
        ]
      end

      it "converts hash messages to message objects" do
        result = provider.send(:normalize_messages, prompt: nil, system: nil, messages: messages)
        expect(result).to all(be_a(Riffer::Agents::Messages::Base))
      end
    end

    context "with message objects" do
      let(:messages) do
        [
          Riffer::Agents::Messages::User.new("Hello"),
          Riffer::Agents::Messages::Assistant.new("Hi there")
        ]
      end

      it "preserves message objects when provided" do
        result = provider.send(:normalize_messages, prompt: nil, system: nil, messages: messages)
        expect(result).to eq(messages)
      end
    end
  end

  describe "#convert_to_message_object" do
    it "raises InvalidInputError when message is not a Hash or Message object" do
      expect {
        provider.send(:convert_to_message_object, "invalid")
      }.to raise_error(Riffer::Agents::InvalidInputError, "Message must be a Hash or Message object, got String")
    end

    it "raises InvalidInputError when message has unknown role" do
      expect {
        provider.send(:convert_to_message_object, {role: "unknown", content: "test"})
      }.to raise_error(Riffer::Agents::InvalidInputError, "Unknown message role: unknown")
    end

    it "converts user hash to User message" do
      result = provider.send(:convert_to_message_object, {role: "user", content: "Hello"})
      expect(result).to be_a(Riffer::Agents::Messages::User)
    end

    it "converts assistant hash to Assistant message" do
      result = provider.send(:convert_to_message_object, {role: "assistant", content: "Hi"})
      expect(result).to be_a(Riffer::Agents::Messages::Assistant)
    end

    it "converts system hash to System message" do
      result = provider.send(:convert_to_message_object, {role: "system", content: "Be helpful"})
      expect(result).to be_a(Riffer::Agents::Messages::System)
    end

    context "with tool message hash" do
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
        expect(result).to be_a(Riffer::Agents::Messages::Tool)
      end
    end

    it "preserves message objects" do
      msg = Riffer::Agents::Messages::User.new("Hello")
      result = provider.send(:convert_to_message_object, msg)
      expect(result).to eq(msg)
    end

    context "with assistant message with tool_calls" do
      let(:assistant_message) do
        {
          role: "assistant",
          content: "Let me search",
          tool_calls: [{id: "1", name: "search"}]
        }
      end

      it "preserves tool_calls in assistant messages" do
        result = provider.send(:convert_to_message_object, assistant_message)
        expect(result.tool_calls).to eq([{id: "1", name: "search"}])
      end
    end
  end

  describe "#has_user_message?" do
    it "returns true for User message object" do
      messages = [Riffer::Agents::Messages::User.new("Hello")]
      expect(provider.send(:has_user_message?, messages)).to be true
    end

    it "returns true for user hash message" do
      messages = [{role: "user", content: "Hello"}]
      expect(provider.send(:has_user_message?, messages)).to be true
    end

    it "returns false when no user messages present" do
      messages = [{role: "system", content: "Be helpful"}]
      expect(provider.send(:has_user_message?, messages)).to be false
    end
  end
end
