# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::Assistant::ToolCall do
  describe "#initialize" do
    it "stores every field" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(
        call_id: "c1",
        name: "get_weather",
        arguments: '{"city":"Paris"}',
      )

      expect(tool_call.call_id).must_equal "c1"
      expect(tool_call.name).must_equal "get_weather"
      expect(tool_call.arguments).must_equal '{"city":"Paris"}'
    end

    it "defaults every field to nil" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new

      expect(tool_call.call_id).must_be_nil
      expect(tool_call.name).must_be_nil
      expect(tool_call.arguments).must_be_nil
    end
  end

  describe ".from_hash" do
    it "builds a tool call from a hash" do
      tool_call = Riffer::Messages::Assistant::ToolCall.from_hash(
        call_id: "c1",
        name: "get_weather",
        arguments: '{"city":"Paris"}',
      )

      expect(tool_call.call_id).must_equal "c1"
      expect(tool_call.name).must_equal "get_weather"
      expect(tool_call.arguments).must_equal '{"city":"Paris"}'
    end

    it "returns a tool call unchanged" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(call_id: "c1", name: "get_weather")

      expect(Riffer::Messages::Assistant::ToolCall.from_hash(tool_call)).must_be_same_as tool_call
    end
  end

  describe "#to_h" do
    it "includes every field, even the ones the call doesn't carry" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(name: "get_weather")

      expect(tool_call.to_h).must_equal({ call_id: nil, name: "get_weather", arguments: nil })
    end

    it "round-trips through from_hash" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(
        call_id: "c1",
        name: "get_weather",
        arguments: '{"city":"Paris"}',
      )

      expect(Riffer::Messages::Assistant::ToolCall.from_hash(tool_call.to_h)).must_equal tool_call
    end
  end

  describe "#==" do
    it "is equal to a tool call with the same fields" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(call_id: "c1", name: "get_weather", arguments: "{}")
      other = Riffer::Messages::Assistant::ToolCall.new(call_id: "c1", name: "get_weather", arguments: "{}")

      expect(tool_call).must_equal other
      expect(tool_call.eql?(other)).must_equal true
      expect(tool_call.hash).must_equal other.hash
    end

    it "differs when any field differs" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(call_id: "c1", name: "get_weather")
      other = Riffer::Messages::Assistant::ToolCall.new(call_id: "c2", name: "get_weather")

      expect(tool_call).wont_equal other
    end

    it "is not equal to a non-tool-call" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(call_id: "c1", name: "get_weather")

      expect(tool_call == { call_id: "c1", name: "get_weather" }).must_equal false
    end

    it "dedupes equal tool calls in a set" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(call_id: "c1", name: "get_weather")
      other = Riffer::Messages::Assistant::ToolCall.new(call_id: "c1", name: "get_weather")

      expect([tool_call, other].uniq.size).must_equal 1
    end
  end
end
