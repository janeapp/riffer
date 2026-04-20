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
end
