# frozen_string_literal: true

require "test_helper"

describe Riffer::Guardrails::Runner do
  let(:pass_guardrail_class) do
    Class.new(Riffer::Guardrail) do
      def process_input(messages, context:)
        pass(messages)
      end

      def process_output(response, messages:, context:)
        pass(response)
      end
    end
  end

  let(:transform_guardrail_class) do
    Class.new(Riffer::Guardrail) do
      def process_input(messages, context:)
        transform(messages.map { |m|
          Riffer::Messages::User.new("[transformed] #{m.content}")
        })
      end

      def process_output(response, messages:, context:)
        transform(Riffer::Messages::Assistant.new("[transformed] #{response.content}"))
      end
    end
  end

  let(:block_guardrail_class) do
    Class.new(Riffer::Guardrail) do
      def process_input(messages, context:)
        block("Input blocked", metadata: {phase: :before})
      end

      def process_output(response, messages:, context:)
        block("Output blocked", metadata: {phase: :after})
      end
    end
  end

  def config_for(klass, **options)
    {class: klass, options: options}
  end

  describe "#run for before phase" do
    it "returns processed messages with no guardrails" do
      runner = Riffer::Guardrails::Runner.new([], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      data, _tripwire, _modifications = runner.run(messages)
      expect(data).must_equal messages
    end

    it "returns nil tripwire when not blocked" do
      runner = Riffer::Guardrails::Runner.new([config_for(pass_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, tripwire, _modifications = runner.run(messages)
      expect(tripwire).must_be_nil
    end

    it "passes messages through pass guardrail" do
      runner = Riffer::Guardrails::Runner.new([config_for(pass_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      data, _tripwire, _modifications = runner.run(messages)
      expect(data.first.content).must_equal "Hello"
    end

    it "transforms messages through transform guardrail" do
      runner = Riffer::Guardrails::Runner.new([config_for(transform_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      data, _tripwire, _modifications = runner.run(messages)
      expect(data.first.content).must_equal "[transformed] Hello"
    end

    it "returns tripwire when blocked" do
      runner = Riffer::Guardrails::Runner.new([config_for(block_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, tripwire, _modifications = runner.run(messages)
      expect(tripwire).wont_be_nil
    end

    it "tripwire has correct reason" do
      runner = Riffer::Guardrails::Runner.new([config_for(block_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, tripwire, _modifications = runner.run(messages)
      expect(tripwire.reason).must_equal "Input blocked"
    end

    it "tripwire has correct phase" do
      runner = Riffer::Guardrails::Runner.new([config_for(block_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, tripwire, _modifications = runner.run(messages)
      expect(tripwire.phase).must_equal :before
    end

    it "tripwire has correct guardrail" do
      runner = Riffer::Guardrails::Runner.new([config_for(block_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, tripwire, _modifications = runner.run(messages)
      expect(tripwire.guardrail).must_equal block_guardrail_class
    end

    it "tripwire has correct metadata" do
      runner = Riffer::Guardrails::Runner.new([config_for(block_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, tripwire, _modifications = runner.run(messages)
      expect(tripwire.metadata).must_equal({phase: :before})
    end
  end

  describe "#run for after phase" do
    it "returns processed response with no guardrails" do
      runner = Riffer::Guardrails::Runner.new([], phase: :after)
      response = Riffer::Messages::Assistant.new("Hi!")
      data, _tripwire, _modifications = runner.run(response, messages: [])
      expect(data).must_equal response
    end

    it "passes response through pass guardrail" do
      runner = Riffer::Guardrails::Runner.new([config_for(pass_guardrail_class)], phase: :after)
      response = Riffer::Messages::Assistant.new("Hi!")
      data, _tripwire, _modifications = runner.run(response, messages: [])
      expect(data.content).must_equal "Hi!"
    end

    it "transforms response through transform guardrail" do
      runner = Riffer::Guardrails::Runner.new([config_for(transform_guardrail_class)], phase: :after)
      response = Riffer::Messages::Assistant.new("Hi!")
      data, _tripwire, _modifications = runner.run(response, messages: [])
      expect(data.content).must_equal "[transformed] Hi!"
    end

    it "returns tripwire when blocked" do
      runner = Riffer::Guardrails::Runner.new([config_for(block_guardrail_class)], phase: :after)
      response = Riffer::Messages::Assistant.new("Hi!")
      _data, tripwire, _modifications = runner.run(response, messages: [])
      expect(tripwire.reason).must_equal "Output blocked"
    end

    it "tripwire has after phase" do
      runner = Riffer::Guardrails::Runner.new([config_for(block_guardrail_class)], phase: :after)
      response = Riffer::Messages::Assistant.new("Hi!")
      _data, tripwire, _modifications = runner.run(response, messages: [])
      expect(tripwire.phase).must_equal :after
    end
  end

  describe "sequential execution" do
    it "chains multiple transform guardrails" do
      configs = [config_for(transform_guardrail_class), config_for(transform_guardrail_class)]
      runner = Riffer::Guardrails::Runner.new(configs, phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      data, _tripwire, _modifications = runner.run(messages)
      expect(data.first.content).must_equal "[transformed] [transformed] Hello"
    end

    it "stops at first blocking guardrail" do
      configs = [config_for(block_guardrail_class), config_for(transform_guardrail_class)]
      runner = Riffer::Guardrails::Runner.new(configs, phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, tripwire, _modifications = runner.run(messages)
      expect(tripwire.guardrail).must_equal block_guardrail_class
    end

    it "returns original data when blocked" do
      runner = Riffer::Guardrails::Runner.new([config_for(block_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      data, _tripwire, _modifications = runner.run(messages)
      expect(data.first.content).must_equal "Hello"
    end
  end

  describe "context passing" do
    let(:context_guardrail_class) do
      Class.new(Riffer::Guardrail) do
        def process_input(messages, context:)
          if context && context[:block]
            block("Context says block")
          else
            pass(messages)
          end
        end
      end
    end

    it "passes context to guardrails" do
      runner = Riffer::Guardrails::Runner.new([config_for(context_guardrail_class)], phase: :before, context: {block: true})
      messages = [Riffer::Messages::User.new("Hello")]
      _data, tripwire, _modifications = runner.run(messages)
      expect(tripwire).wont_be_nil
    end

    it "works without context" do
      runner = Riffer::Guardrails::Runner.new([config_for(context_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, tripwire, _modifications = runner.run(messages)
      expect(tripwire).must_be_nil
    end
  end

  describe "guardrail options" do
    let(:options_guardrail_class) do
      Class.new(Riffer::Guardrail) do
        attr_reader :prefix

        def initialize(prefix: "[default]")
          super()
          @prefix = prefix
        end

        def process_input(messages, context:)
          transform(messages.map { |m|
            Riffer::Messages::User.new("#{prefix} #{m.content}")
          })
        end
      end
    end

    it "passes options to guardrail constructor" do
      runner = Riffer::Guardrails::Runner.new([config_for(options_guardrail_class, prefix: "[custom]")], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      data, _tripwire, _modifications = runner.run(messages)
      expect(data.first.content).must_equal "[custom] Hello"
    end

    it "uses default options when none provided" do
      runner = Riffer::Guardrails::Runner.new([config_for(options_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      data, _tripwire, _modifications = runner.run(messages)
      expect(data.first.content).must_equal "[default] Hello"
    end
  end

  describe "modifications" do
    it "returns empty modifications when all guardrails pass" do
      runner = Riffer::Guardrails::Runner.new([config_for(pass_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, _tripwire, modifications = runner.run(messages)
      expect(modifications).must_be_empty
    end

    it "returns modification when a guardrail transforms" do
      runner = Riffer::Guardrails::Runner.new([config_for(transform_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, _tripwire, modifications = runner.run(messages)
      expect(modifications.length).must_equal 1
    end

    it "modification has correct guardrail" do
      runner = Riffer::Guardrails::Runner.new([config_for(transform_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, _tripwire, modifications = runner.run(messages)
      expect(modifications.first.guardrail).must_equal transform_guardrail_class
    end

    it "modification has correct phase" do
      runner = Riffer::Guardrails::Runner.new([config_for(transform_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, _tripwire, modifications = runner.run(messages)
      expect(modifications.first.phase).must_equal :before
    end

    it "modification has correct message_indices" do
      runner = Riffer::Guardrails::Runner.new([config_for(transform_guardrail_class)], phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, _tripwire, modifications = runner.run(messages)
      expect(modifications.first.message_indices).must_equal [0]
    end

    it "returns multiple modifications for chained transforms" do
      configs = [config_for(transform_guardrail_class), config_for(transform_guardrail_class)]
      runner = Riffer::Guardrails::Runner.new(configs, phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, _tripwire, modifications = runner.run(messages)
      expect(modifications.length).must_equal 2
    end

    it "returns collected modifications when a later guardrail blocks" do
      configs = [config_for(transform_guardrail_class), config_for(block_guardrail_class)]
      runner = Riffer::Guardrails::Runner.new(configs, phase: :before)
      messages = [Riffer::Messages::User.new("Hello")]
      _data, tripwire, modifications = runner.run(messages)
      expect(tripwire).wont_be_nil
      expect(modifications.length).must_equal 1
    end

    it "detects correct indices when only some messages change" do
      selective_guardrail_class = Class.new(Riffer::Guardrail) do
        def process_input(messages, context:)
          transformed = messages.map.with_index { |m, i|
            (i == 1) ? Riffer::Messages::User.new("[changed] #{m.content}") : m
          }
          transform(transformed)
        end
      end

      runner = Riffer::Guardrails::Runner.new([config_for(selective_guardrail_class)], phase: :before)
      messages = [
        Riffer::Messages::User.new("First"),
        Riffer::Messages::User.new("Second"),
        Riffer::Messages::User.new("Third")
      ]
      _data, _tripwire, modifications = runner.run(messages)
      expect(modifications.first.message_indices).must_equal [1]
    end

    it "returns modification with index 0 for after phase transform" do
      runner = Riffer::Guardrails::Runner.new([config_for(transform_guardrail_class)], phase: :after)
      response = Riffer::Messages::Assistant.new("Hi!")
      _data, _tripwire, modifications = runner.run(response, messages: [])
      expect(modifications.first.message_indices).must_equal [0]
    end
  end
end
