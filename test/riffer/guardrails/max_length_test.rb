# frozen_string_literal: true

require "test_helper"

describe Riffer::Guardrails::MaxLength do
  describe "#initialize" do
    it "defaults max to 10_000" do
      guardrail = Riffer::Guardrails::MaxLength.new
      expect(guardrail.max).must_equal 10_000
    end

    it "accepts custom max" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 100)
      expect(guardrail.max).must_equal 100
    end
  end

  describe ".identifier" do
    it "has default identifier" do
      expect(Riffer::Guardrails::MaxLength.identifier).must_equal "riffer/guardrails/max_length"
    end
  end

  describe "#process_input" do
    it "passes messages under the limit" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 100)
      messages = [Riffer::Messages::User.new("Hello")]
      result = guardrail.process_input(messages, context: nil)
      expect(result.pass?).must_equal true
    end

    it "returns original messages when passing" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 100)
      messages = [Riffer::Messages::User.new("Hello")]
      result = guardrail.process_input(messages, context: nil)
      expect(result.data).must_equal messages
    end

    it "blocks messages over the limit" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 5)
      messages = [Riffer::Messages::User.new("Hello World")]
      result = guardrail.process_input(messages, context: nil)
      expect(result.block?).must_equal true
    end

    it "includes length in block metadata" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 5)
      messages = [Riffer::Messages::User.new("Hello World")]
      result = guardrail.process_input(messages, context: nil)
      expect(result.metadata[:length]).must_equal 11
    end

    it "includes max in block metadata" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 5)
      messages = [Riffer::Messages::User.new("Hello World")]
      result = guardrail.process_input(messages, context: nil)
      expect(result.metadata[:max]).must_equal 5
    end

    it "checks all messages" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 10)
      messages = [
        Riffer::Messages::User.new("Short"),
        Riffer::Messages::User.new("This is a very long message")
      ]
      result = guardrail.process_input(messages, context: nil)
      expect(result.block?).must_equal true
    end

    it "passes messages exactly at the limit" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 5)
      messages = [Riffer::Messages::User.new("Hello")]
      result = guardrail.process_input(messages, context: nil)
      expect(result.pass?).must_equal true
    end

    it "handles messages without content" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 5)
      messages = [Riffer::Messages::Assistant.new("", tool_calls: [{id: "1", name: "test", arguments: "{}"}])]
      result = guardrail.process_input(messages, context: nil)
      expect(result.pass?).must_equal true
    end
  end

  describe "#process_output" do
    it "passes response under the limit" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 100)
      response = Riffer::Messages::Assistant.new("Hello")
      result = guardrail.process_output(response, messages: [], context: nil)
      expect(result.pass?).must_equal true
    end

    it "returns original response when passing" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 100)
      response = Riffer::Messages::Assistant.new("Hello")
      result = guardrail.process_output(response, messages: [], context: nil)
      expect(result.data).must_equal response
    end

    it "blocks response over the limit" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 5)
      response = Riffer::Messages::Assistant.new("Hello World")
      result = guardrail.process_output(response, messages: [], context: nil)
      expect(result.block?).must_equal true
    end

    it "includes length in block metadata" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 5)
      response = Riffer::Messages::Assistant.new("Hello World")
      result = guardrail.process_output(response, messages: [], context: nil)
      expect(result.metadata[:length]).must_equal 11
    end

    it "includes max in block metadata" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 5)
      response = Riffer::Messages::Assistant.new("Hello World")
      result = guardrail.process_output(response, messages: [], context: nil)
      expect(result.metadata[:max]).must_equal 5
    end

    it "passes response exactly at the limit" do
      guardrail = Riffer::Guardrails::MaxLength.new(max: 5)
      response = Riffer::Messages::Assistant.new("Hello")
      result = guardrail.process_output(response, messages: [], context: nil)
      expect(result.pass?).must_equal true
    end
  end
end
