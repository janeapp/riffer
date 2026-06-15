# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::Base do
  let(:base_message) { Riffer::Messages::Base.new("Test content") }

  describe "#initialize" do
    it "sets the content" do
      expect(base_message.content).must_equal "Test content"
    end
  end

  describe "#role" do
    it "raises NotImplementedError" do
      error = expect { base_message.role }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #role"
    end
  end

  describe "#to_h" do
    it "raises NotImplementedError when role is not implemented" do
      expect { base_message.to_h }.must_raise(NotImplementedError)
    end
  end

  describe "#has_tool_calls?" do
    it "defaults to false" do
      expect(base_message.has_tool_calls?).must_equal false
    end

    it "is false on non-assistant subclasses" do
      expect(Riffer::Messages::User.new("Hi").has_tool_calls?).must_equal false
    end
  end

  describe "#id" do
    before { @original_strategy = Riffer.config.message_id_strategy }
    after { Riffer.config.message_id_strategy = @original_strategy }

    it "defaults to nil when strategy is :none" do
      Riffer.config.message_id_strategy = :none
      expect(Riffer::Messages::User.new("Hi").id).must_be_nil
    end

    it "auto-populates a UUID when strategy is :uuid" do
      Riffer.config.message_id_strategy = :uuid
      id = Riffer::Messages::User.new("Hi").id
      expect(id).must_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "auto-populates a UUIDv7 when strategy is :uuidv7" do
      Riffer.config.message_id_strategy = :uuidv7
      id = Riffer::Messages::User.new("Hi").id
      expect(id).must_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "generates different ids for different messages" do
      Riffer.config.message_id_strategy = :uuidv7
      a = Riffer::Messages::User.new("Hi").id
      b = Riffer::Messages::User.new("Hi").id
      expect(a).wont_equal b
    end

    it "preserves an explicit id over auto-generation" do
      Riffer.config.message_id_strategy = :uuidv7
      msg = Riffer::Messages::User.new("Hi", id: "explicit-id")
      expect(msg.id).must_equal "explicit-id"
    end

    it "includes :id in to_h when present" do
      msg = Riffer::Messages::User.new("Hi", id: "abc-123")
      expect(msg.to_h[:id]).must_equal "abc-123"
    end

    it "omits :id from to_h when nil" do
      Riffer.config.message_id_strategy = :none
      msg = Riffer::Messages::User.new("Hi")
      expect(msg.to_h.key?(:id)).must_equal false
    end
  end

  describe ".from_hash" do
    it "raises ArgumentError when message is not a Hash or Message object" do
      error = expect {
        Riffer::Messages::Base.from_hash("invalid")
      }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "Message must be a Hash or Message object, got String"
    end

    it "raises ArgumentError when message has unknown role" do
      error = expect {
        Riffer::Messages::Base.from_hash({role: "unknown", content: "test"})
      }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "Unknown message role: unknown"
    end

    it "raises ArgumentError when message is missing role key" do
      error = expect {
        Riffer::Messages::Base.from_hash({content: "test"})
      }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "Message hash must include a 'role' key"
    end

    it "converts user hash to User message" do
      result = Riffer::Messages::Base.from_hash({role: "user", content: "Hello"})
      expect(result).must_be_instance_of Riffer::Messages::User
      expect(result.content).must_equal "Hello"
    end

    it "converts assistant hash to Assistant message" do
      result = Riffer::Messages::Base.from_hash({role: "assistant", content: "Hi"})
      expect(result).must_be_instance_of Riffer::Messages::Assistant
      expect(result.content).must_equal "Hi"
    end

    it "converts system hash to System message" do
      result = Riffer::Messages::Base.from_hash({role: "system", content: "Be helpful"})
      expect(result).must_be_instance_of Riffer::Messages::System
      expect(result.content).must_equal "Be helpful"
    end

    it "converts tool hash to Tool message" do
      result = Riffer::Messages::Base.from_hash({role: "tool", content: "Result", tool_call_id: "123", name: "search"})
      expect(result).must_be_instance_of Riffer::Messages::Tool
      expect(result.content).must_equal "Result"
      expect(result.tool_call_id).must_equal "123"
      expect(result.name).must_equal "search"
    end

    it "preserves message objects" do
      msg = Riffer::Messages::User.new("Hello")
      result = Riffer::Messages::Base.from_hash(msg)
      expect(result).must_equal msg
    end

    describe "with :id in hash" do
      it "propagates id to User messages" do
        result = Riffer::Messages::Base.from_hash({role: "user", content: "Hi", id: "u-1"})
        expect(result.id).must_equal "u-1"
      end

      it "propagates id to Assistant messages" do
        result = Riffer::Messages::Base.from_hash({role: "assistant", content: "Hi", id: "a-1"})
        expect(result.id).must_equal "a-1"
      end

      it "propagates id to System messages" do
        result = Riffer::Messages::Base.from_hash({role: "system", content: "Be nice", id: "s-1"})
        expect(result.id).must_equal "s-1"
      end

      it "propagates id to Tool messages" do
        result = Riffer::Messages::Base.from_hash({role: "tool", content: "ok", tool_call_id: "c-1", name: "x", id: "t-1"})
        expect(result.id).must_equal "t-1"
      end
    end

    describe "with assistant structured_output" do
      it "preserves structured_output from hash with symbol keys" do
        result = Riffer::Messages::Base.from_hash({role: "assistant", content: '{"sentiment":"positive"}', structured_output: {sentiment: "positive"}})
        expect(result.structured_output?).must_equal true
        expect(result.structured_output).must_equal({sentiment: "positive"})
      end

      it "defaults to nil when not provided" do
        result = Riffer::Messages::Base.from_hash({role: "assistant", content: "Hello"})
        expect(result.structured_output?).must_equal false
        expect(result.structured_output).must_be_nil
      end
    end

    describe "with assistant finish_reason" do
      it "restores a string finish_reason as a symbol" do
        result = Riffer::Messages::Base.from_hash({role: "assistant", content: "Hello", finish_reason: "stop"})
        expect(result.finish_reason).must_equal :stop
      end

      it "defaults to nil when not provided" do
        result = Riffer::Messages::Base.from_hash({role: "assistant", content: "Hello"})
        expect(result.finish_reason).must_be_nil
      end
    end

    describe "with assistant tool_calls" do
      let(:tool_call) { Riffer::Messages::Assistant::ToolCall.new(name: "search") }

      it "preserves tool_calls in assistant messages" do
        result = Riffer::Messages::Base.from_hash({role: "assistant", content: "Let me search", tool_calls: [tool_call]})
        expect(result.tool_calls).must_equal [tool_call]
      end

      it "converts tool_call hashes to ToolCall structs" do
        result = Riffer::Messages::Base.from_hash({
          role: "assistant",
          content: "Let me search",
          tool_calls: [{call_id: "c1", name: "search", arguments: "{}"}]
        })
        tc = result.tool_calls.first
        expect(tc).must_be_instance_of Riffer::Messages::Assistant::ToolCall
        expect(tc.call_id).must_equal "c1"
        expect(tc.name).must_equal "search"
        expect(tc.arguments).must_equal "{}"
      end
    end

    describe "with user files" do
      it "converts file hashes to FilePart objects" do
        result = Riffer::Messages::Base.from_hash({
          role: "user",
          content: "Describe this",
          files: [{data: "aGVsbG8=", media_type: "image/png"}]
        })
        expect(result.files.length).must_equal 1
        expect(result.files.first).must_be_instance_of Riffer::Messages::FilePart
      end

      it "preserves FilePart objects" do
        file = Riffer::Messages::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
        result = Riffer::Messages::Base.from_hash({role: "user", content: "Describe this", files: [file]})
        expect(result.files.first).must_equal file
      end

      it "defaults to empty files when not provided" do
        result = Riffer::Messages::Base.from_hash({role: "user", content: "Hello"})
        expect(result.files).must_equal []
      end
    end
  end
end
