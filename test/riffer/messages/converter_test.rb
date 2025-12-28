# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::Converter do
  let(:klass) do
    Class.new do
      include Riffer::Messages::Converter
    end
  end

  let(:instance) { klass.new }

  describe "#convert_to_message_object" do
    it "raises InvalidInputError when message is not a Hash or Message object" do
      error = expect {
        instance.convert_to_message_object("invalid")
      }.must_raise(Riffer::Messages::InvalidInputError)
      expect(error.message).must_equal "Message must be a Hash or Message object, got String"
    end

    it "raises InvalidInputError when message has unknown role" do
      error = expect {
        instance.convert_to_message_object({role: "unknown", content: "test"})
      }.must_raise(Riffer::Messages::InvalidInputError)
      expect(error.message).must_equal "Unknown message role: unknown"
    end

    it "raises InvalidInputError when message is missing role key" do
      error = expect {
        instance.convert_to_message_object({content: "test"})
      }.must_raise(Riffer::Messages::InvalidInputError)
      expect(error.message).must_equal "Message hash must include a 'role' key"
    end

    it "converts user hash to User message" do
      result = instance.convert_to_message_object({role: "user", content: "Hello"})
      expect(result).must_be_instance_of Riffer::Messages::User
      expect(result.content).must_equal "Hello"
    end

    it "converts assistant hash to Assistant message" do
      result = instance.convert_to_message_object({role: "assistant", content: "Hi"})
      expect(result).must_be_instance_of Riffer::Messages::Assistant
      expect(result.content).must_equal "Hi"
    end

    it "converts system hash to System message" do
      result = instance.convert_to_message_object({role: "system", content: "Be helpful"})
      expect(result).must_be_instance_of Riffer::Messages::System
      expect(result.content).must_equal "Be helpful"
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
        result = instance.convert_to_message_object(tool_message)
        expect(result).must_be_instance_of Riffer::Messages::Tool
        expect(result.content).must_equal "Result"
        expect(result.tool_call_id).must_equal "123"
        expect(result.name).must_equal "search"
      end
    end

    it "preserves message objects" do
      msg = Riffer::Messages::User.new("Hello")
      result = instance.convert_to_message_object(msg)
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
        result = instance.convert_to_message_object(assistant_message)
        expect(result.tool_calls).must_equal [{id: "1", name: "search"}]
      end
    end

    it "handles string keys in hashes" do
      result = instance.convert_to_message_object({"role" => "user", "content" => "Hello"})
      expect(result).must_be_instance_of Riffer::Messages::User
      expect(result.content).must_equal "Hello"
    end
  end
end
