# frozen_string_literal: true

require "test_helper"

describe Riffer::ExternalAgent::Response do
  describe "#initialize" do
    it "stores the content via the parent" do
      response = Riffer::ExternalAgent::Response.new("Hello")
      expect(response.content).must_equal "Hello"
    end

    it "defaults tool_calls to an empty array" do
      response = Riffer::ExternalAgent::Response.new("Hello")
      expect(response.tool_calls).must_equal []
    end

    it "stores tool_calls" do
      calls = [Riffer::ExternalAgent::ToolCall.new(name: "search", arguments: {q: "ruby"})]
      response = Riffer::ExternalAgent::Response.new("Hello", tool_calls: calls)
      expect(response.tool_calls).must_equal calls
    end

    it "passes messages through to the parent" do
      messages = [Riffer::Messages::User.new("Hi"), Riffer::Messages::Assistant.new("Hello")]
      response = Riffer::ExternalAgent::Response.new("Hello", messages: messages)
      expect(response.messages).must_equal messages
    end

    it "passes token_usage through to the parent" do
      usage = Riffer::TokenUsage.new(input_tokens: 10, output_tokens: 20)
      response = Riffer::ExternalAgent::Response.new("Hello", token_usage: usage)
      expect(response.token_usage).must_equal usage
    end

    it "passes vendor_metadata through to the parent and freezes it" do
      response = Riffer::ExternalAgent::Response.new("Hello", vendor_metadata: {model: "claude"})
      expect(response.vendor_metadata).must_equal({model: "claude"})
      expect(response.vendor_metadata.frozen?).must_equal true
    end

    it "defaults resolved_identifier to nil" do
      response = Riffer::ExternalAgent::Response.new("Hello")
      expect(response.resolved_identifier).must_be_nil
    end

    it "passes resolved_identifier through to the parent" do
      response = Riffer::ExternalAgent::Response.new("Hello", resolved_identifier: "claude-code/2.1.131")
      expect(response.resolved_identifier).must_equal "claude-code/2.1.131"
    end
  end

  describe "inheritance" do
    it "is a Riffer::AgentResponse" do
      response = Riffer::ExternalAgent::Response.new("Hello")
      expect(response).must_be_kind_of Riffer::AgentResponse
    end

    it "reports success? true by default" do
      response = Riffer::ExternalAgent::Response.new("Hello")
      expect(response.success?).must_equal true
    end
  end
end
