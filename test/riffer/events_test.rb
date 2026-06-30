# frozen_string_literal: true

require "test_helper"

describe Riffer::Events do
  after do
    Riffer.config.events.clear
    Riffer.config.events.on_error = Riffer::Config::Events::DEFAULT_ERROR_HANDLER
  end

  def chat_event
    Riffer::Events::ChatCompleted.new(provider: "mock", duration: 0.1)
  end

  describe "#subscribed?" do
    it "is false with no subscribers" do
      expect(Riffer::Events.subscribed?).must_equal false
    end

    it "is true once a subscriber is registered" do
      Riffer.config.events.subscribe(->(event) {})
      expect(Riffer::Events.subscribed?).must_equal true
    end
  end

  describe "#publish" do
    it "delivers the event to a subscriber" do
      received = []
      Riffer.config.events.subscribe(->(event) { received << event })
      event = chat_event
      Riffer::Events.publish(event)
      expect(received).must_equal [event]
    end

    it "delivers to every subscriber" do
      counts = []
      Riffer.config.events.subscribe(->(event) { counts << :a })
      Riffer.config.events.subscribe(->(event) { counts << :b })
      Riffer::Events.publish(chat_event)
      expect(counts).must_equal [:a, :b]
    end

    it "continues delivery when a subscriber raises" do
      received = []
      Riffer.config.events.subscribe(->(event) { raise "boom" })
      Riffer.config.events.subscribe(->(event) { received << event })
      Riffer::Events.publish(chat_event)
      expect(received.length).must_equal 1
    end

    it "routes a subscriber error to on_error" do
      errors = []
      Riffer.config.events.on_error = ->(error, event) { errors << error }
      Riffer.config.events.subscribe(->(event) { raise "boom" })
      Riffer::Events.publish(chat_event)
      expect(errors.first).must_be_instance_of RuntimeError
    end

    it "isolates an error raised by the on_error handler" do
      received = []
      Riffer.config.events.on_error = ->(error, event) { raise "handler boom" }
      Riffer.config.events.subscribe(->(event) { raise "boom" })
      Riffer.config.events.subscribe(->(event) { received << event })
      Riffer::Events.publish(chat_event)
      expect(received.length).must_equal 1
    end
  end
end

describe Riffer::Events::ChatCompleted do
  it "exposes the dotted event name" do
    expect(Riffer::Events::ChatCompleted.new(provider: "mock", duration: 0.1).name).must_equal "riffer.chat"
  end

  it "exposes the operation" do
    expect(Riffer::Events::ChatCompleted.new(provider: "mock", duration: 0.1).operation).must_equal :chat
  end

  it "derives cost from the token usage" do
    usage = Riffer::Providers::TokenUsage.new(input_tokens: 1, output_tokens: 1, cost: 0.5)
    expect(Riffer::Events::ChatCompleted.new(provider: "mock", duration: 0.1, token_usage: usage).cost).must_equal 0.5
  end

  it "reports no error when error_type is nil" do
    expect(Riffer::Events::ChatCompleted.new(provider: "mock", duration: 0.1).error?).must_equal false
  end

  it "reports an error when error_type is set" do
    expect(Riffer::Events::ChatCompleted.new(provider: "mock", duration: 0.1, error_type: "RuntimeError").error?).must_equal true
  end
end

describe Riffer::Events::AgentInvoked do
  it "exposes the dotted event name" do
    expect(Riffer::Events::AgentInvoked.new(agent: "a", provider: "mock", duration: 0.1, steps: 2).name).must_equal "riffer.invoke_agent"
  end

  it "carries the run step count" do
    expect(Riffer::Events::AgentInvoked.new(agent: "a", provider: "mock", duration: 0.1, steps: 3).steps).must_equal 3
  end
end

describe Riffer::Events::ToolExecuted do
  it "exposes the dotted event name" do
    expect(Riffer::Events::ToolExecuted.new(tool: "t", call_id: "c", outcome: :success, duration: 0.1).name).must_equal "riffer.execute_tool"
  end

  it "carries the outcome" do
    expect(Riffer::Events::ToolExecuted.new(tool: "t", call_id: "c", outcome: :error, duration: 0.1).outcome).must_equal :error
  end
end

describe Riffer::Events::GuardrailExecuted do
  it "exposes the dotted event name" do
    expect(Riffer::Events::GuardrailExecuted.new(guardrail: "g", phase: :before, duration: 0.1).name).must_equal "riffer.execute_guardrail"
  end

  it "carries the outcome action" do
    expect(Riffer::Events::GuardrailExecuted.new(guardrail: "g", phase: :before, duration: 0.1, outcome: :block).outcome).must_equal :block
  end
end
