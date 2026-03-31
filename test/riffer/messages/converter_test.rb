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
    it "raises ArgumentError when message is not a Hash or Message object" do
      error = expect {
        instance.convert_to_message_object("invalid")
      }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "Message must be a Hash or Message object, got String"
    end

    it "raises ArgumentError when message has unknown role" do
      error = expect {
        instance.convert_to_message_object({role: "unknown", content: "test"})
      }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "Unknown message role: unknown"
    end

    it "raises ArgumentError when message is missing role key" do
      error = expect {
        instance.convert_to_message_object({content: "test"})
      }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "Message hash must include a 'role' key"
    end

    it "converts user hash to User message" do
      result = instance.convert_to_message_object({role: "user", content: "Hello"})
      expect(result).must_be_instance_of Riffer::Messages::User
      expect(result.content).must_equal "Hello"
    end

    describe "with timestamp" do
      it "parses ISO 8601 timestamp string" do
        ts = "2025-01-15T12:00:00.000+00:00"
        result = instance.convert_to_message_object({role: "user", content: "Hello", timestamp: ts})
        expect(result.timestamp).must_equal Time.iso8601(ts)
      end

      it "passes through Time objects" do
        custom_time = Time.new(2025, 1, 15, 12, 0, 0)
        result = instance.convert_to_message_object({role: "user", content: "Hello", timestamp: custom_time})
        expect(result.timestamp).must_equal custom_time
      end

      it "defaults timestamp when not provided" do
        before = Time.now
        result = instance.convert_to_message_object({role: "user", content: "Hello"})
        after = Time.now
        expect(result.timestamp).must_be :>=, before
        expect(result.timestamp).must_be :<=, after
      end

      it "round-trips timestamp through to_h" do
        custom_time = Time.new(2025, 1, 15, 12, 0, 0)
        msg = Riffer::Messages::User.new("Hello", timestamp: custom_time)
        result = instance.convert_to_message_object(msg.to_h)
        expect(result.timestamp).must_equal Time.iso8601(custom_time.iso8601(3))
      end
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

    describe "with assistant message with structured_output" do
      it "preserves structured_output from hash with symbol keys" do
        result = instance.convert_to_message_object({role: "assistant", content: '{"sentiment":"positive"}', structured_output: {sentiment: "positive"}})
        expect(result.structured_output?).must_equal true
        expect(result.structured_output).must_equal({sentiment: "positive"})
      end

      it "defaults to nil when not provided" do
        result = instance.convert_to_message_object({role: "assistant", content: "Hello"})
        expect(result.structured_output?).must_equal false
        expect(result.structured_output).must_be_nil
      end
    end

    describe "with assistant message with tool_calls" do
      let(:tool_call) { Riffer::Messages::Assistant::ToolCall.new(id: "1", name: "search") }

      let(:assistant_message) do
        {
          role: "assistant",
          content: "Let me search",
          tool_calls: [tool_call]
        }
      end

      it "preserves tool_calls in assistant messages" do
        result = instance.convert_to_message_object(assistant_message)
        expect(result.tool_calls).must_equal [tool_call]
      end

      it "converts tool_call hashes to ToolCall structs" do
        result = instance.convert_to_message_object({
          role: "assistant",
          content: "Let me search",
          tool_calls: [{id: "1", call_id: "c1", name: "search", arguments: "{}"}]
        })
        tc = result.tool_calls.first
        expect(tc).must_be_instance_of Riffer::Messages::Assistant::ToolCall
        expect(tc.id).must_equal "1"
        expect(tc.call_id).must_equal "c1"
        expect(tc.name).must_equal "search"
        expect(tc.arguments).must_equal "{}"
      end
    end

    describe "with user message with files" do
      it "converts file hashes to FilePart objects" do
        result = instance.convert_to_message_object({
          role: "user",
          content: "Describe this",
          files: [{data: "aGVsbG8=", media_type: "image/png"}]
        })
        expect(result.files.length).must_equal 1
      end

      it "converts file hashes to correct type" do
        result = instance.convert_to_message_object({
          role: "user",
          content: "Describe this",
          files: [{data: "aGVsbG8=", media_type: "image/png"}]
        })
        expect(result.files.first).must_be_instance_of Riffer::FilePart
      end

      it "preserves FilePart objects" do
        file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
        result = instance.convert_to_message_object({
          role: "user",
          content: "Describe this",
          files: [file]
        })
        expect(result.files.first).must_equal file
      end

      it "defaults to empty files when not provided" do
        result = instance.convert_to_message_object({role: "user", content: "Hello"})
        expect(result.files).must_equal []
      end
    end
  end

  describe "#convert_to_file_part" do
    it "passes through FilePart objects" do
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      result = instance.convert_to_file_part(file)
      expect(result).must_equal file
    end

    it "converts url hash" do
      result = instance.convert_to_file_part({url: "https://example.com/photo.jpg", media_type: "image/jpeg"})
      expect(result).must_be_instance_of Riffer::FilePart
      expect(result.url).must_equal "https://example.com/photo.jpg"
    end

    it "converts data hash" do
      result = instance.convert_to_file_part({data: "aGVsbG8=", media_type: "image/png"})
      expect(result).must_be_instance_of Riffer::FilePart
      expect(result.data).must_equal "aGVsbG8="
    end

    it "raises for invalid hash" do
      error = expect {
        instance.convert_to_file_part({media_type: "image/png"})
      }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/must include :url or :data/)
    end

    it "raises for non-hash non-FilePart" do
      error = expect {
        instance.convert_to_file_part("invalid")
      }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/must be a Hash or FilePart/)
    end
  end
end
