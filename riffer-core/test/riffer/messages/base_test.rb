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
    it "raises ArgumentError when message has unknown role" do
      error = expect do
        Riffer::Messages::Base.from_hash({ role: "unknown", content: "test" })
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "Unknown message role: unknown"
    end

    it "raises ArgumentError when message is missing role key" do
      error = expect do
        Riffer::Messages::Base.from_hash({ content: "test" })
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "Message hash must include a 'role' key"
    end

    it "converts user hash to User message" do
      result = Riffer::Messages::Base.from_hash({ role: "user", content: "Hello" })

      expect(result).must_be_instance_of Riffer::Messages::User
      expect(result.content).must_equal "Hello"
    end

    it "converts assistant hash to Assistant message" do
      result = Riffer::Messages::Base.from_hash({ role: "assistant", content: "Hi" })

      expect(result).must_be_instance_of Riffer::Messages::Assistant
      expect(result.content).must_equal "Hi"
    end

    it "converts system hash to System message" do
      result = Riffer::Messages::Base.from_hash({ role: "system", content: "Be helpful" })

      expect(result).must_be_instance_of Riffer::Messages::System
      expect(result.content).must_equal "Be helpful"
    end

    it "converts tool hash to Tool message" do
      result = Riffer::Messages::Base.from_hash({ role: "tool", content: "Result", tool_call_id: "123", name: "x" })

      expect(result).must_be_instance_of Riffer::Messages::Tool
      expect(result.content).must_equal "Result"
    end

    it "preserves message objects" do
      msg = Riffer::Messages::User.new("Hello")
      result = Riffer::Messages::Base.from_hash(msg)

      expect(result).must_equal msg
    end
  end
end
