# frozen_string_literal: true

require "test_helper"

describe Riffer::Guardrail do
  describe ".identifier" do
    it "derives the snake_case identifier from the class name" do
      expect(Riffer::Guardrail.identifier).must_equal "riffer/guardrail"
    end

    it "derives the identifier once and reuses it" do
      klass = Class.new(Riffer::Guardrail)
      Object.const_set(:GuardrailTestMemoizedGuardrail, klass)

      expect(klass.identifier).must_equal "guardrail_test_memoized_guardrail"

      with_class_name_converter_returning("re-derived") do
        expect(klass.identifier).must_equal "guardrail_test_memoized_guardrail"
      end
    ensure
      Object.send(:remove_const, :GuardrailTestMemoizedGuardrail)
    end

    it "does not cache an identifier derived before the class is named" do
      klass = Class.new(Riffer::Guardrail)

      expect(klass.identifier).must_equal ""

      Object.const_set(:GuardrailTestLateNamedGuardrail, klass)

      expect(klass.identifier).must_equal "guardrail_test_late_named_guardrail"
    ensure
      Object.send(:remove_const, :GuardrailTestLateNamedGuardrail)
    end
  end

  describe "#name" do
    it "returns the class-level identifier" do
      expect(Riffer::Guardrail.new.name).must_equal "riffer/guardrail"
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
        def process_input(messages, context:)
          transform(messages.map { |m| Riffer::Messages::User.new(m.content.upcase) })
        end

        def process_output(_response, messages:, context:)
          block("Blocked for testing", metadata: { test: true })
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

      expect(result.metadata).must_equal({ test: true })
    end
  end
end
