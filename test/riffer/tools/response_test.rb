# frozen_string_literal: true

require "test_helper"

describe Riffer::Tools::Response do
  describe ".success" do
    it "creates a successful response" do
      response = Riffer::Tools::Response.success("result")
      expect(response.success?).must_equal true
    end

    it "sets the content" do
      response = Riffer::Tools::Response.success("result")
      expect(response.content).must_equal "result"
    end

    it "converts result to string with text format" do
      response = Riffer::Tools::Response.success(123)
      expect(response.content).must_equal "123"
    end

    it "defaults to text format" do
      response = Riffer::Tools::Response.success({name: "Alice"})
      expect(response.content).must_include "Alice"
    end

    it "converts to JSON with json format" do
      response = Riffer::Tools::Response.success({name: "Alice", age: 30}, format: :json)
      expect(response.content).must_equal '{"name":"Alice","age":30}'
    end

    it "converts nested structures to JSON" do
      response = Riffer::Tools::Response.success({user: {name: "Bob"}, items: [1, 2, 3]}, format: :json)
      expect(response.content).must_equal '{"user":{"name":"Bob"},"items":[1,2,3]}'
    end

    it "converts arrays to JSON" do
      response = Riffer::Tools::Response.success([1, 2, 3], format: :json)
      expect(response.content).must_equal "[1,2,3]"
    end

    it "raises for invalid format" do
      error = expect {
        Riffer::Tools::Response.success("result", format: :xml)
      }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Invalid format/)
    end

    it "has no error_message" do
      response = Riffer::Tools::Response.success("result")
      expect(response.error_message).must_be_nil
    end

    it "has no error_type" do
      response = Riffer::Tools::Response.success("result")
      expect(response.error_type).must_be_nil
    end

    it "is not an error" do
      response = Riffer::Tools::Response.success("result")
      expect(response.error?).must_equal false
    end
  end

  describe ".text" do
    it "creates a success response with text format" do
      response = Riffer::Tools::Response.text("hello")
      expect(response.success?).must_equal true
      expect(response.content).must_equal "hello"
    end

    it "converts to string" do
      response = Riffer::Tools::Response.text(123)
      expect(response.content).must_equal "123"
    end
  end

  describe ".json" do
    it "creates a success response with JSON format" do
      response = Riffer::Tools::Response.json({name: "Alice"})
      expect(response.success?).must_equal true
      expect(response.content).must_equal '{"name":"Alice"}'
    end

    it "converts arrays to JSON" do
      response = Riffer::Tools::Response.json([1, 2, 3])
      expect(response.content).must_equal "[1,2,3]"
    end
  end

  describe ".error" do
    it "creates an error response" do
      response = Riffer::Tools::Response.error("something failed")
      expect(response.error?).must_equal true
    end

    it "is not successful" do
      response = Riffer::Tools::Response.error("something failed")
      expect(response.success?).must_equal false
    end

    it "sets the content to the message" do
      response = Riffer::Tools::Response.error("something failed")
      expect(response.content).must_equal "something failed"
    end

    it "sets the error_message" do
      response = Riffer::Tools::Response.error("something failed")
      expect(response.error_message).must_equal "something failed"
    end

    it "defaults error_type to execution_error" do
      response = Riffer::Tools::Response.error("something failed")
      expect(response.error_type).must_equal :execution_error
    end

    it "accepts any symbol as error_type" do
      response = Riffer::Tools::Response.error("failed", type: :custom_error)
      expect(response.error_type).must_equal :custom_error
    end
  end

  describe "#to_h" do
    it "returns hash with content for success" do
      response = Riffer::Tools::Response.success("result")
      expect(response.to_h[:content]).must_equal "result"
    end

    it "returns hash with nil error for success" do
      response = Riffer::Tools::Response.success("result")
      expect(response.to_h[:error]).must_be_nil
    end

    it "returns hash with nil error_type for success" do
      response = Riffer::Tools::Response.success("result")
      expect(response.to_h[:error_type]).must_be_nil
    end

    it "returns hash with content for error" do
      response = Riffer::Tools::Response.error("failed")
      expect(response.to_h[:content]).must_equal "failed"
    end

    it "returns hash with error message for error" do
      response = Riffer::Tools::Response.error("failed")
      expect(response.to_h[:error]).must_equal "failed"
    end

    it "returns hash with error_type for error" do
      response = Riffer::Tools::Response.error("failed", type: :validation_error)
      expect(response.to_h[:error_type]).must_equal :validation_error
    end
  end

  describe "VALID_FORMATS" do
    it "includes text" do
      expect(Riffer::Tools::Response::VALID_FORMATS).must_include :text
    end

    it "includes json" do
      expect(Riffer::Tools::Response::VALID_FORMATS).must_include :json
    end
  end
end
