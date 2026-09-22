# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::Tool do
  describe "#role" do
    it "returns tool" do
      message = Riffer::Messages::Tool.new("Result", tool_call_id: "123", name: "my_tool")

      expect(message.role).must_equal :tool
    end
  end

  describe ".from_hash" do
    it "builds a Tool message with its id, tool_call_id, and name" do
      message = Riffer::Messages::Tool.from_hash(
        { role: "tool", content: "Result", id: "t-1", tool_call_id: "123", name: "my_tool" },
      )

      expect(message).must_be_instance_of Riffer::Messages::Tool
      expect(message.content).must_equal "Result"
      expect(message.id).must_equal "t-1"
      expect(message.tool_call_id).must_equal "123"
      expect(message.name).must_equal "my_tool"
    end

    it "returns a Tool message unchanged" do
      message = Riffer::Messages::Tool.new("Result", tool_call_id: "123", name: "my_tool")

      expect(Riffer::Messages::Tool.from_hash(message)).must_be_same_as message
    end

    it "round-trips an errored message through to_h" do
      message = Riffer::Messages::Tool.new(
        "Error: Unknown tool 'foo'",
        tool_call_id: "123",
        name: "foo",
        error: "Unknown tool 'foo'",
        error_type: :unknown_tool,
      )

      rebuilt = Riffer::Messages::Tool.from_hash(message.to_h)

      expect(rebuilt.error?).must_equal true
      expect(rebuilt.error).must_equal "Unknown tool 'foo'"
      expect(rebuilt.error_type).must_equal :unknown_tool
    end

    it "round-trips an errored message through a JSON round trip" do
      message = Riffer::Messages::Tool.new(
        "Error: Unknown tool 'foo'",
        tool_call_id: "123",
        name: "foo",
        error: "Unknown tool 'foo'",
        error_type: :unknown_tool,
      )

      json = JSON.parse(JSON.generate(message.to_h), symbolize_names: true)
      rebuilt = Riffer::Messages::Tool.from_hash(json)

      expect(rebuilt.error?).must_equal true
      expect(rebuilt.error).must_equal "Unknown tool 'foo'"
      expect(rebuilt.error_type).must_equal :unknown_tool
    end
  end

  describe "#to_h" do
    it "returns hash with role, content, tool_call_id, and name" do
      message = Riffer::Messages::Tool.new("Result", tool_call_id: "123", name: "my_tool")
      expected = { role: :tool, content: "Result", tool_call_id: "123", name: "my_tool" }

      expect(message.to_h).must_equal expected
    end

    it "includes error and error_type when present" do
      message = Riffer::Messages::Tool.new(
        "Error: Unknown tool 'foo'",
        tool_call_id: "123",
        name: "foo",
        error: "Unknown tool 'foo'",
        error_type: :unknown_tool,
      )
      expected = {
        role: :tool,
        content: "Error: Unknown tool 'foo'",
        tool_call_id: "123",
        name: "foo",
        error: "Unknown tool 'foo'",
        error_type: :unknown_tool,
      }

      expect(message.to_h).must_equal expected
    end

    it "excludes error fields when not present" do
      message = Riffer::Messages::Tool.new("Success", tool_call_id: "123", name: "my_tool")

      expect(message.to_h.key?(:error)).must_equal false
      expect(message.to_h.key?(:error_type)).must_equal false
    end
  end

  describe "#error?" do
    it "returns false when no error" do
      message = Riffer::Messages::Tool.new("Result", tool_call_id: "123", name: "my_tool")

      expect(message.error?).must_equal false
    end

    it "returns true when error is present" do
      message = Riffer::Messages::Tool.new(
        "Error: Something went wrong",
        tool_call_id: "123",
        name: "my_tool",
        error: "Something went wrong",
        error_type: :execution_error,
      )

      expect(message.error?).must_equal true
    end
  end

  describe "error attributes" do
    it "stores error message" do
      message = Riffer::Messages::Tool.new(
        "Error: Unknown tool",
        tool_call_id: "123",
        name: "foo",
        error: "Unknown tool 'foo'",
        error_type: :unknown_tool,
      )

      expect(message.error).must_equal "Unknown tool 'foo'"
    end

    it "stores error type" do
      message = Riffer::Messages::Tool.new(
        "Validation error: city is required",
        tool_call_id: "123",
        name: "weather",
        error: "city is required",
        error_type: :validation_error,
      )

      expect(message.error_type).must_equal :validation_error
    end
  end
end
