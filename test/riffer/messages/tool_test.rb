# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::Tool do
  describe "#role" do
    it "returns tool" do
      message = Riffer::Messages::Tool.new("Result", tool_call_id: "123", name: "my_tool")
      expect(message.role).must_equal "tool"
    end
  end

  describe "#to_h" do
    it "returns hash with role, content, tool_call_id, and name" do
      message = Riffer::Messages::Tool.new("Result", tool_call_id: "123", name: "my_tool")
      expected = {role: "tool", content: "Result", tool_call_id: "123", name: "my_tool"}
      expect(message.to_h).must_equal expected
    end

    it "includes error and error_type when present" do
      message = Riffer::Messages::Tool.new(
        "Error: Unknown tool 'foo'",
        tool_call_id: "123",
        name: "foo",
        error: "Unknown tool 'foo'",
        error_type: :unknown_tool
      )
      expected = {
        role: "tool",
        content: "Error: Unknown tool 'foo'",
        tool_call_id: "123",
        name: "foo",
        error: "Unknown tool 'foo'",
        error_type: :unknown_tool
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
        error_type: :execution_error
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
        error_type: :unknown_tool
      )
      expect(message.error).must_equal "Unknown tool 'foo'"
    end

    it "stores error type" do
      message = Riffer::Messages::Tool.new(
        "Validation error: city is required",
        tool_call_id: "123",
        name: "weather",
        error: "city is required",
        error_type: :validation_error
      )
      expect(message.error_type).must_equal :validation_error
    end
  end
end
