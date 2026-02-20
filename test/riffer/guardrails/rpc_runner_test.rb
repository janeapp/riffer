# frozen_string_literal: true

require "test_helper"

describe Riffer::Guardrails::RpcRunner do
  let(:messages) { [Riffer::Messages::User.new("Hello")] }

  describe "#run with :pass action" do
    it "returns data unchanged" do
      definitions = [{name: "PassGuardrail", phase: :before, options_json: nil}]
      callback = ->(name, phase, data, options_json) { {action: :pass} }
      runner = Riffer::Guardrails::RpcRunner.new(definitions, phase: :before, callback: callback)

      data, tripwire, modifications = runner.run(messages)

      expect(data).must_equal messages
      expect(tripwire).must_be_nil
      expect(modifications).must_be_empty
    end
  end

  describe "#run with :block action" do
    it "returns a tripwire" do
      definitions = [{name: "BlockGuardrail", phase: :before, options_json: nil}]
      callback = ->(name, phase, data, options_json) {
        {action: :block, block_reason: "Blocked!", metadata_json: '{"reason":"test"}'}
      }
      runner = Riffer::Guardrails::RpcRunner.new(definitions, phase: :before, callback: callback)

      _data, tripwire, _modifications = runner.run(messages)

      expect(tripwire).wont_be_nil
      expect(tripwire.reason).must_equal "Blocked!"
      expect(tripwire.guardrail).must_equal "BlockGuardrail"
      expect(tripwire.phase).must_equal :before
      expect(tripwire.metadata).must_equal({reason: "test"})
    end

    it "stops processing remaining guardrails" do
      call_count = 0
      definitions = [
        {name: "BlockGuardrail", phase: :before, options_json: nil},
        {name: "NeverReached", phase: :before, options_json: nil}
      ]
      callback = ->(name, phase, data, options_json) {
        call_count += 1
        {action: :block, block_reason: "Blocked!"}
      }
      runner = Riffer::Guardrails::RpcRunner.new(definitions, phase: :before, callback: callback)

      runner.run(messages)

      expect(call_count).must_equal 1
    end
  end

  describe "#run with :transform action" do
    it "returns a modification" do
      transformed = [Riffer::Messages::User.new("[transformed] Hello")]
      definitions = [{name: "TransformGuardrail", phase: :before, options_json: nil}]
      callback = ->(name, phase, data, options_json) {
        {action: :transform, messages: transformed, modified_message_indices: [0]}
      }
      runner = Riffer::Guardrails::RpcRunner.new(definitions, phase: :before, callback: callback)

      data, tripwire, modifications = runner.run(messages)

      expect(data).must_equal transformed
      expect(tripwire).must_be_nil
      expect(modifications.length).must_equal 1
      expect(modifications.first.guardrail).must_equal "TransformGuardrail"
      expect(modifications.first.phase).must_equal :before
      expect(modifications.first.message_indices).must_equal [0]
    end
  end

  describe "phase filtering" do
    it "skips guardrails that do not match the phase" do
      call_count = 0
      definitions = [
        {name: "AfterOnly", phase: :after, options_json: nil},
        {name: "BeforeOnly", phase: :before, options_json: nil}
      ]
      callback = ->(name, phase, data, options_json) {
        call_count += 1
        {action: :pass}
      }
      runner = Riffer::Guardrails::RpcRunner.new(definitions, phase: :before, callback: callback)

      runner.run(messages)

      expect(call_count).must_equal 1
    end

    it "includes guardrails with nil phase" do
      call_count = 0
      definitions = [{name: "AnyPhase", phase: nil, options_json: nil}]
      callback = ->(name, phase, data, options_json) {
        call_count += 1
        {action: :pass}
      }
      runner = Riffer::Guardrails::RpcRunner.new(definitions, phase: :before, callback: callback)

      runner.run(messages)

      expect(call_count).must_equal 1
    end
  end

  describe "chaining multiple guardrails" do
    it "passes transformed data to the next guardrail" do
      received_data = []
      first_transformed = [Riffer::Messages::User.new("first")]
      second_transformed = [Riffer::Messages::User.new("second")]

      definitions = [
        {name: "First", phase: :before, options_json: nil},
        {name: "Second", phase: :before, options_json: nil}
      ]
      callback = ->(name, phase, data, options_json) {
        received_data << data
        case name
        when "First"
          {action: :transform, messages: first_transformed, modified_message_indices: [0]}
        when "Second"
          {action: :transform, messages: second_transformed, modified_message_indices: [0]}
        end
      }
      runner = Riffer::Guardrails::RpcRunner.new(definitions, phase: :before, callback: callback)

      data, _, modifications = runner.run(messages)

      expect(received_data[0]).must_equal messages
      expect(received_data[1]).must_equal first_transformed
      expect(data).must_equal second_transformed
      expect(modifications.length).must_equal 2
    end
  end

  describe "options_json forwarding" do
    it "passes options_json to the callback" do
      received_options = nil
      definitions = [{name: "Guardrail", phase: :before, options_json: '{"threshold":0.5}'}]
      callback = ->(name, phase, data, options_json) {
        received_options = options_json
        {action: :pass}
      }
      runner = Riffer::Guardrails::RpcRunner.new(definitions, phase: :before, callback: callback)

      runner.run(messages)

      expect(received_options).must_equal '{"threshold":0.5}'
    end
  end
end
