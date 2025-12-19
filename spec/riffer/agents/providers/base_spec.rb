# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Providers::Base do
  let(:provider) { described_class.new }

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

    it "converts hash messages to message objects" do
      messages = [
        {role: "user", content: "Hello"},
        {role: "assistant", content: "Hi there"}
      ]
      result = provider.send(:normalize_messages, prompt: nil, system: nil, messages: messages)
      expect(result).to all(be_a(Riffer::Agents::Messages::Base))
    end

    it "preserves message objects when provided" do
      messages = [
        Riffer::Agents::Messages::User.new("Hello"),
        Riffer::Agents::Messages::Assistant.new("Hi there")
      ]
      result = provider.send(:normalize_messages, prompt: nil, system: nil, messages: messages)
      expect(result).to eq(messages)
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

    it "converts tool hash to Tool message" do
      result = provider.send(:convert_to_message_object, {
        role: "tool",
        content: "Result",
        tool_call_id: "123",
        name: "search"
      })
      expect(result).to be_a(Riffer::Agents::Messages::Tool)
    end

    it "preserves message objects" do
      msg = Riffer::Agents::Messages::User.new("Hello")
      result = provider.send(:convert_to_message_object, msg)
      expect(result).to eq(msg)
    end

    it "preserves tool_calls in assistant messages" do
      result = provider.send(:convert_to_message_object, {
        role: "assistant",
        content: "Let me search",
        tool_calls: [{id: "1", name: "search"}]
      })
      expect(result.tool_calls).to eq([{id: "1", name: "search"}])
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
