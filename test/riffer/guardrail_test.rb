# frozen_string_literal: true

require "test_helper"

describe Riffer::Guardrail do
  describe ".identifier" do
    it "defaults to snake_case class name" do
      expect(Riffer::Guardrail.identifier).must_equal "riffer/guardrail"
    end

    it "can be set explicitly" do
      guardrail_class = Class.new(Riffer::Guardrail) do
        identifier "custom_guardrail"
      end
      expect(guardrail_class.identifier).must_equal "custom_guardrail"
    end

    it "converts non-string identifiers to string" do
      guardrail_class = Class.new(Riffer::Guardrail) do
        identifier :my_guardrail
      end
      expect(guardrail_class.identifier).must_equal "my_guardrail"
    end
  end

  describe "#identifier" do
    it "returns the class identifier" do
      guardrail_class = Class.new(Riffer::Guardrail) do
        identifier "instance_guardrail"
      end
      guardrail = guardrail_class.new
      expect(guardrail.identifier).must_equal "instance_guardrail"
    end
  end

  describe "#process_input" do
    it "returns pass by default" do
      guardrail = Riffer::Guardrail.new
      messages = [Riffer::Messages::User.new("Hello")]
      result = guardrail.process_input(messages, context: nil)
      expect(result.pass?).must_equal true
    end

    it "returns the original messages" do
      guardrail = Riffer::Guardrail.new
      messages = [Riffer::Messages::User.new("Hello")]
      result = guardrail.process_input(messages, context: nil)
      expect(result.data).must_equal messages
    end
  end

  describe "#process_output" do
    it "returns pass by default" do
      guardrail = Riffer::Guardrail.new
      response = Riffer::Messages::Assistant.new("Hi there!")
      result = guardrail.process_output(response, messages: [], context: nil)
      expect(result.pass?).must_equal true
    end

    it "returns the original response" do
      guardrail = Riffer::Guardrail.new
      response = Riffer::Messages::Assistant.new("Hi there!")
      result = guardrail.process_output(response, messages: [], context: nil)
      expect(result.data).must_equal response
    end
  end

  describe "custom guardrail" do
    let(:custom_guardrail_class) do
      Class.new(Riffer::Guardrail) do
        identifier "custom_transformer"

        def process_input(messages, context:)
          transform(messages.map { |m| Riffer::Messages::User.new(m.content.upcase) })
        end

        def process_output(response, messages:, context:)
          block("Blocked for testing", metadata: {test: true})
        end
      end
    end

    it "can transform input" do
      guardrail = custom_guardrail_class.new
      messages = [Riffer::Messages::User.new("hello")]
      result = guardrail.process_input(messages, context: nil)
      expect(result.transform?).must_equal true
    end

    it "transforms message content" do
      guardrail = custom_guardrail_class.new
      messages = [Riffer::Messages::User.new("hello")]
      result = guardrail.process_input(messages, context: nil)
      expect(result.data.first.content).must_equal "HELLO"
    end

    it "can block output" do
      guardrail = custom_guardrail_class.new
      response = Riffer::Messages::Assistant.new("Response")
      result = guardrail.process_output(response, messages: [], context: nil)
      expect(result.block?).must_equal true
    end

    it "provides block reason" do
      guardrail = custom_guardrail_class.new
      response = Riffer::Messages::Assistant.new("Response")
      result = guardrail.process_output(response, messages: [], context: nil)
      expect(result.data).must_equal "Blocked for testing"
    end

    it "provides block metadata" do
      guardrail = custom_guardrail_class.new
      response = Riffer::Messages::Assistant.new("Response")
      result = guardrail.process_output(response, messages: [], context: nil)
      expect(result.metadata).must_equal({test: true})
    end
  end
end
