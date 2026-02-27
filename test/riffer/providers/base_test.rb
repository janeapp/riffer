# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Base do
  let(:provider) { Riffer::Providers::Base.new }

  describe "#generate_text" do
    it "raises NotImplementedError when hook methods not implemented" do
      error = expect { provider.generate_text(prompt: "Hello") }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #build_request_params"
    end

    it "raises ArgumentError when no prompt or messages provided" do
      error = expect { provider.generate_text }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "prompt is required when messages is not provided"
    end

    it "raises ArgumentError when both prompt and messages provided" do
      error = expect do
        provider.generate_text(prompt: "Hello", messages: [{role: "user", content: "Hi"}])
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "cannot provide both prompt and messages"
    end

    it "raises ArgumentError when both system and messages provided" do
      error = expect do
        provider.generate_text(system: "You are helpful", messages: [{role: "user", content: "Hi"}])
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "cannot provide both system and messages"
    end

    it "raises ArgumentError when messages has no user message" do
      error = expect do
        provider.generate_text(messages: [{role: "system", content: "You are helpful"}])
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "messages must include at least one user message"
    end
  end

  describe "#stream_text" do
    it "raises NotImplementedError when hook methods not implemented" do
      error = expect { provider.stream_text(prompt: "Hello") }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #build_request_params"
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

  describe "#strict_schema" do
    it "makes optional properties nullable and required" do
      schema = {
        type: "object",
        properties: {
          "name" => {type: "string"},
          "age" => {type: "integer"}
        },
        required: ["name"],
        additionalProperties: false
      }

      result = provider.send(:strict_schema, schema)

      expect(result[:required]).must_include "name"
      expect(result[:required]).must_include "age"
      expect(result[:properties]["name"][:type]).must_equal "string"
      expect(result[:properties]["age"][:type]).must_equal ["integer", "null"]
    end

    it "recurses into nested objects" do
      schema = {
        type: "object",
        properties: {
          "address" => {
            type: "object",
            properties: {
              "city" => {type: "string"},
              "zip" => {type: "string"}
            },
            required: ["city"],
            additionalProperties: false
          }
        },
        required: ["address"],
        additionalProperties: false
      }

      result = provider.send(:strict_schema, schema)
      address = result[:properties]["address"]

      expect(address[:required]).must_include "city"
      expect(address[:required]).must_include "zip"
      expect(address[:properties]["city"][:type]).must_equal "string"
      expect(address[:properties]["zip"][:type]).must_equal ["string", "null"]
    end

    it "recurses into array items" do
      schema = {
        type: "object",
        properties: {
          "items" => {
            type: "array",
            items: {
              type: "object",
              properties: {
                "name" => {type: "string"},
                "note" => {type: "string"}
              },
              required: ["name"],
              additionalProperties: false
            }
          }
        },
        required: ["items"],
        additionalProperties: false
      }

      result = provider.send(:strict_schema, schema)
      items_schema = result[:properties]["items"][:items]

      expect(items_schema[:required]).must_include "name"
      expect(items_schema[:required]).must_include "note"
      expect(items_schema[:properties]["name"][:type]).must_equal "string"
      expect(items_schema[:properties]["note"][:type]).must_equal ["string", "null"]
    end

    it "preserves already-nullable types" do
      schema = {
        type: "object",
        properties: {
          "field" => {type: ["string", "null"]}
        },
        required: [],
        additionalProperties: false
      }

      result = provider.send(:strict_schema, schema)

      expect(result[:properties]["field"][:type]).must_equal ["string", "null"]
    end

    it "returns non-object schemas unchanged" do
      schema = {type: "string"}
      result = provider.send(:strict_schema, schema)
      expect(result).must_equal schema
    end
  end
end
