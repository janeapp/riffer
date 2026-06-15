# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::Assistant do
  describe "#role" do
    it "returns assistant" do
      message = Riffer::Messages::Assistant.new("I can help")
      expect(message.role).must_equal :assistant
    end
  end

  describe "#token_usage" do
    it "returns nil by default" do
      message = Riffer::Messages::Assistant.new("I can help")
      expect(message.token_usage).must_be_nil
    end

    it "returns usage when provided" do
      usage = Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      message = Riffer::Messages::Assistant.new("I can help", token_usage: usage)
      expect(message.token_usage).must_equal usage
    end
  end

  describe "#structured_output?" do
    it "returns false by default" do
      message = Riffer::Messages::Assistant.new("I can help")
      expect(message.structured_output?).must_equal false
    end

    it "returns true when structured_output is provided" do
      message = Riffer::Messages::Assistant.new('{"sentiment":"positive"}', structured_output: {sentiment: "positive"})
      expect(message.structured_output?).must_equal true
    end
  end

  describe "#structured_output" do
    it "returns nil when not provided" do
      message = Riffer::Messages::Assistant.new('{"sentiment":"positive"}')
      expect(message.structured_output).must_be_nil
    end

    it "returns the stored hash" do
      message = Riffer::Messages::Assistant.new('{"sentiment":"positive"}', structured_output: {sentiment: "positive"})
      expect(message.structured_output).must_equal({sentiment: "positive"})
    end
  end

  describe "#has_tool_calls?" do
    it "returns false when tool_calls is empty" do
      message = Riffer::Messages::Assistant.new("hi")
      expect(message.has_tool_calls?).must_equal false
    end

    it "returns true when tool_calls is non-empty" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(call_id: "c1", name: "t", arguments: "{}")
      message = Riffer::Messages::Assistant.new("", tool_calls: [tool_call])
      expect(message.has_tool_calls?).must_equal true
    end
  end

  describe "#+" do
    it "concatenates content" do
      a = Riffer::Messages::Assistant.new("Part one")
      b = Riffer::Messages::Assistant.new("Part two")

      result = a + b

      expect(result.content).must_equal "Part one\n\nPart two"
    end

    it "returns an Assistant message" do
      a = Riffer::Messages::Assistant.new("Part one")
      b = Riffer::Messages::Assistant.new("Part two")

      result = a + b

      expect(result).must_be_instance_of Riffer::Messages::Assistant
    end

    it "combines tool calls from both messages" do
      tc_a = Riffer::Messages::Assistant::ToolCall.new(call_id: "1", name: "foo", arguments: "{}")
      tc_b = Riffer::Messages::Assistant::ToolCall.new(call_id: "2", name: "bar", arguments: "{}")
      a = Riffer::Messages::Assistant.new("First", tool_calls: [tc_a])
      b = Riffer::Messages::Assistant.new("Second", tool_calls: [tc_b])

      result = a + b

      expect(result.tool_calls).must_equal [tc_a, tc_b]
    end

    it "discards token_usage and structured_output" do
      usage = Riffer::Providers::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      a = Riffer::Messages::Assistant.new("First", token_usage: usage, structured_output: {key: "val"})
      b = Riffer::Messages::Assistant.new("Second")

      result = a + b

      expect(result.token_usage).must_be_nil
      expect(result.structured_output).must_be_nil
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      message = Riffer::Messages::Assistant.new("I can help")
      expect(message.to_h).must_equal({role: :assistant, content: "I can help"})
    end

    it "includes tool_calls when provided" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(name: "test")
      message = Riffer::Messages::Assistant.new("Using tool", tool_calls: [tool_call])
      expect(message.to_h[:tool_calls]).must_equal [{call_id: nil, name: "test", arguments: nil}]
    end

    it "excludes tool_calls when empty" do
      message = Riffer::Messages::Assistant.new("No tools")
      expect(message.to_h).must_equal({role: :assistant, content: "No tools"})
    end

    it "includes usage when provided" do
      usage = Riffer::Providers::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      message = Riffer::Messages::Assistant.new("I can help", token_usage: usage)
      expect(message.to_h[:token_usage]).must_equal({input_tokens: 100, output_tokens: 50})
    end

    it "excludes usage when nil" do
      message = Riffer::Messages::Assistant.new("No usage")
      expect(message.to_h.key?(:usage)).must_equal false
    end

    it "includes structured_output when present" do
      message = Riffer::Messages::Assistant.new('{"sentiment":"positive"}', structured_output: {sentiment: "positive"})
      expect(message.to_h[:structured_output]).must_equal({sentiment: "positive"})
    end

    it "excludes structured_output when nil" do
      message = Riffer::Messages::Assistant.new("No structured output")
      expect(message.to_h.key?(:structured_output)).must_equal false
    end

    it "includes finish_reason when present" do
      message = Riffer::Messages::Assistant.new("Done", finish_reason: :stop)
      expect(message.to_h[:finish_reason]).must_equal :stop
    end

    it "excludes finish_reason when nil" do
      message = Riffer::Messages::Assistant.new("No finish reason")
      expect(message.to_h.key?(:finish_reason)).must_equal false
    end
  end

  describe "#finish_reason" do
    it "exposes the normalized finish reason" do
      message = Riffer::Messages::Assistant.new("Truncated", finish_reason: :length)
      expect(message.finish_reason).must_equal :length
    end

    it "defaults to nil" do
      message = Riffer::Messages::Assistant.new("No finish reason")
      expect(message.finish_reason).must_be_nil
    end

    it "raises on a value outside the normalized vocabulary" do
      error = expect { Riffer::Messages::Assistant.new("Bad", finish_reason: :bogus) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_include ":bogus"
    end
  end
end
