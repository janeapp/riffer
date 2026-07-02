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

  def tool_event
    Riffer::Events::ToolExecuted.new(tool: "t", call_id: "c", outcome: :success, duration: 0.1)
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

  describe "type-filtered subscription" do
    it "delivers only the subscribed type" do
      chats = []
      Riffer.config.events.subscribe(Riffer::Events::ChatCompleted) { |event| chats << event }
      Riffer::Events.publish(chat_event)
      Riffer::Events.publish(tool_event)
      expect(chats.length).must_equal 1
      expect(chats.first).must_be_instance_of Riffer::Events::ChatCompleted
    end

    it "delivers every event to an untyped subscriber" do
      all = []
      Riffer.config.events.subscribe { |event| all << event }
      Riffer::Events.publish(chat_event)
      Riffer::Events.publish(tool_event)
      expect(all.length).must_equal 2
    end

    it "raises when the type filter is not an event class" do
      expect { Riffer.config.events.subscribe(String) { |event| } }.must_raise Riffer::ArgumentError
    end

    it "unsubscribes a type-filtered subscriber" do
      received = []
      handle = Riffer.config.events.subscribe(Riffer::Events::ChatCompleted) { |event| received << event }
      Riffer.config.events.unsubscribe(handle)
      Riffer::Events.publish(chat_event)
      expect(received).must_be_empty
    end
  end

  describe "#observe" do
    it "returns the block result" do
      result = Riffer::Events.observe("op", attributes: {}, kind: :internal, event: ->(_result, _outcome) {}) { |_span| 42 }
      expect(result).must_equal 42
    end

    it "does not let an event-builder failure break the operation" do
      Riffer.config.events.subscribe(->(event) {})
      result = Riffer::Events.observe("op", attributes: {}, kind: :internal, event: ->(_result, _outcome) { raise "build boom" }) { |_span| 42 }
      expect(result).must_equal 42
    end

    it "publishes the built event to subscribers" do
      received = []
      Riffer.config.events.subscribe(->(event) { received << event })
      builder = ->(_result, outcome) { Riffer::Events::ChatCompleted.new(provider: "mock", **outcome.to_h) }
      Riffer::Events.observe("op", attributes: {}, kind: :internal, event: builder) { |_span| 42 }
      expect(received.length).must_equal 1
      expect(received.first).must_be_instance_of Riffer::Events::ChatCompleted
    end

    it "emits on the failure path with the error on the event" do
      received = []
      Riffer.config.events.subscribe(->(event) { received << event })
      builder = ->(_result, outcome) { Riffer::Events::ChatCompleted.new(provider: "mock", **outcome.to_h) }
      expect {
        Riffer::Events.observe("op", attributes: {}, kind: :internal, event: builder) { |_span| raise "boom" }
      }.must_raise RuntimeError
      expect(received.length).must_equal 1
      expect(received.first.error).must_be_instance_of RuntimeError
      expect(received.first.error_type).must_equal "RuntimeError"
    end
  end
end

describe Riffer::Events::ChatCompleted do
  it "exposes the dotted event name" do
    expect(Riffer::Events::ChatCompleted.new(provider: "mock", duration: 0.1).name).must_equal "riffer.chat"
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

  it "derives error_type from a raised exception" do
    event = Riffer::Events::ChatCompleted.new(provider: "mock", duration: 0.1, error: RuntimeError.new("boom"))
    expect(event.error_type).must_equal "RuntimeError"
    expect(event.error?).must_equal true
  end

  describe "generic surface" do
    it "exposes measurements including duration, token counts, and cost" do
      usage = Riffer::Providers::TokenUsage.new(input_tokens: 10, output_tokens: 5, cost: 0.5)
      event = Riffer::Events::ChatCompleted.new(provider: "openai", model: "gpt-4", duration: 0.2, token_usage: usage)
      expect(event.measurements["duration"]).must_equal 0.2
      expect(event.measurements["input_tokens"]).must_equal 10
      expect(event.measurements["output_tokens"]).must_equal 5
      expect(event.measurements["cost"]).must_equal 0.5
    end

    it "exposes low-cardinality dimensions" do
      event = Riffer::Events::ChatCompleted.new(provider: "openai", model: "gpt-4", duration: 0.2)
      expect(event.dimensions).must_equal({"provider" => "openai", "model" => "gpt-4"})
    end

    it "adds error_type to dimensions on failure" do
      event = Riffer::Events::ChatCompleted.new(provider: "openai", duration: 0.2, error_type: "RuntimeError")
      expect(event.dimensions["error_type"]).must_equal "RuntimeError"
    end

    it "merges tags under dimensions in labels" do
      event = Riffer::Events::ChatCompleted.new(provider: "openai", duration: 0.2, tags: {"team" => "growth"})
      expect(event.labels).must_equal({"team" => "growth", "provider" => "openai"})
    end

    it "keeps dimensions authoritative over a colliding tag" do
      event = Riffer::Events::ChatCompleted.new(provider: "openai", duration: 0.2, tags: {"provider" => "spoofed"})
      expect(event.labels["provider"]).must_equal "openai"
    end
  end
end

describe Riffer::Events::AgentInvoked do
  it "exposes the dotted event name" do
    expect(Riffer::Events::AgentInvoked.new(agent: "a", provider: "mock", duration: 0.1, steps: 2).name).must_equal "riffer.invoke_agent"
  end

  it "carries the run step count" do
    expect(Riffer::Events::AgentInvoked.new(agent: "a", provider: "mock", duration: 0.1, steps: 3).steps).must_equal 3
  end

  it "reports the step count as a measurement" do
    expect(Riffer::Events::AgentInvoked.new(agent: "a", provider: "mock", duration: 0.1, steps: 3).measurements["steps"]).must_equal 3
  end
end

describe Riffer::Events::ToolExecuted do
  it "exposes the dotted event name" do
    expect(Riffer::Events::ToolExecuted.new(tool: "t", call_id: "c", outcome: :success, duration: 0.1).name).must_equal "riffer.execute_tool"
  end

  it "carries the outcome" do
    expect(Riffer::Events::ToolExecuted.new(tool: "t", call_id: "c", outcome: :error, duration: 0.1).outcome).must_equal :error
  end

  it "exposes tool and outcome as dimensions without the call id" do
    dims = Riffer::Events::ToolExecuted.new(tool: "get_weather", call_id: "c1", outcome: :success, duration: 0.1).dimensions
    expect(dims).must_equal({"tool" => "get_weather", "outcome" => "success"})
  end

  it "projects to a flat hash for logging" do
    h = Riffer::Events::ToolExecuted.new(tool: "get_weather", call_id: "c1", outcome: :success, duration: 0.1, tags: {"team" => "growth"}).to_h
    expect(h["name"]).must_equal "riffer.execute_tool"
    expect(h["tool"]).must_equal "get_weather"
    expect(h["duration"]).must_equal 0.1
    expect(h["tag.team"]).must_equal "growth"
  end
end

describe Riffer::Events::GuardrailExecuted do
  it "exposes the dotted event name" do
    expect(Riffer::Events::GuardrailExecuted.new(guardrail: "g", phase: :before, duration: 0.1).name).must_equal "riffer.execute_guardrail"
  end

  it "carries the outcome action" do
    expect(Riffer::Events::GuardrailExecuted.new(guardrail: "g", phase: :before, duration: 0.1, outcome: :block).outcome).must_equal :block
  end

  it "exposes guardrail, phase, and action as dimensions" do
    dims = Riffer::Events::GuardrailExecuted.new(guardrail: "profanity", phase: :before, duration: 0.1, outcome: :block).dimensions
    expect(dims).must_equal({"guardrail" => "profanity", "phase" => "before", "action" => "block"})
  end
end
