# frozen_string_literal: true

require "test_helper"

describe Riffer::AgentResponse do
  describe "#initialize" do
    it "stores the content" do
      response = Riffer::AgentResponse.new("Hello")
      expect(response.content).must_equal "Hello"
    end

    it "defaults messages to an empty array" do
      response = Riffer::AgentResponse.new("Hello")
      expect(response.messages).must_equal []
    end

    it "stores messages" do
      messages = [Riffer::Messages::User.new("Hi"), Riffer::Messages::Assistant.new("Hello")]
      response = Riffer::AgentResponse.new("Hello", messages: messages)
      expect(response.messages).must_equal messages
    end

    it "defaults token_usage to nil" do
      response = Riffer::AgentResponse.new("Hello")
      expect(response.token_usage).must_be_nil
    end

    it "stores token_usage" do
      usage = Riffer::TokenUsage.new(input_tokens: 10, output_tokens: 20)
      response = Riffer::AgentResponse.new("Hello", token_usage: usage)
      expect(response.token_usage).must_equal usage
    end

    it "defaults vendor_metadata to an empty frozen hash" do
      response = Riffer::AgentResponse.new("Hello")
      expect(response.vendor_metadata).must_equal({})
      expect(response.vendor_metadata.frozen?).must_equal true
    end

    it "stores vendor_metadata and freezes it on construction" do
      response = Riffer::AgentResponse.new("Hello", vendor_metadata: {model: "gpt-4o"})
      expect(response.vendor_metadata).must_equal({model: "gpt-4o"})
      expect(response.vendor_metadata.frozen?).must_equal true
    end

    it "defaults resolved_identifier to nil" do
      response = Riffer::AgentResponse.new("Hello")
      expect(response.resolved_identifier).must_be_nil
    end

    it "stores resolved_identifier when given" do
      response = Riffer::AgentResponse.new("Hello", resolved_identifier: "vendor/1.2.3")
      expect(response.resolved_identifier).must_equal "vendor/1.2.3"
    end
  end

  describe "#success?" do
    it "returns true by default" do
      response = Riffer::AgentResponse.new("Hello")
      expect(response.success?).must_equal true
    end
  end
end
