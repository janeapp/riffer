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
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
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

  describe "#to_h" do
    it "returns hash with role and content" do
      message = Riffer::Messages::Assistant.new("I can help")
      expect(message.to_h).must_equal({role: :assistant, content: "I can help"})
    end

    it "includes tool_calls when provided" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(id: "1", name: "test")
      message = Riffer::Messages::Assistant.new("Using tool", tool_calls: [tool_call])
      expect(message.to_h[:tool_calls]).must_equal [{id: "1", call_id: nil, name: "test", arguments: nil}]
    end

    it "excludes tool_calls when empty" do
      message = Riffer::Messages::Assistant.new("No tools")
      expect(message.to_h).must_equal({role: :assistant, content: "No tools"})
    end

    it "includes usage when provided" do
      usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
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
  end
end
