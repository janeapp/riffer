# frozen_string_literal: true

require "test_helper"

describe Riffer::Agent::Run do
  let(:agent_class) do
    Class.new(Riffer::Agent) do
      identifier "test-agent"
      model "mock/riffer-1"
      instructions "You are a helpful assistant."
    end
  end

  describe ".generate" do
    it "returns a Riffer::Agent::Response" do
      agent = agent_class.new
      response = Riffer::Agent::Run.generate(agent: agent, prompt: "hi")
      expect(response).must_be_instance_of Riffer::Agent::Response
    end

    it "raises when files: is given without a prompt" do
      agent = agent_class.new
      err = expect { Riffer::Agent::Run.generate(agent: agent, files: [{url: "https://x.com/a.png", media_type: "image/png"}]) }.must_raise Riffer::ArgumentError
      expect(err.message).must_match(/files: requires a prompt/)
    end
  end

  describe ".stream" do
    it "returns an Enumerator" do
      agent = agent_class.new
      expect(Riffer::Agent::Run.stream(agent: agent, prompt: "hi")).must_be_instance_of Enumerator
    end

    it "raises when structured_output is configured" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        structured_output do
          required :sentiment, String
        end
      end
      agent = klass.new
      err = expect { agent.stream("hi") }.must_raise Riffer::ArgumentError
      expect(err.message).must_match(/Structured output is not supported with streaming/)
    end

    it "raises when files: is given without a prompt" do
      agent = agent_class.new
      err = expect { agent.stream(nil, files: [{url: "https://x.com/a.png", media_type: "image/png"}]) }.must_raise Riffer::ArgumentError
      expect(err.message).must_match(/files: requires a prompt/)
    end
  end

  describe "#generate with structured_output" do
    it "returns Response with parsed structured_output from class-level schema" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        structured_output do
          required :sentiment, String
          required :score, Float
        end
      end

      agent = klass.new
      provider = agent.provider
      provider.stub_response('{"sentiment":"positive","score":0.9}')

      result = agent.generate("Analyze sentiment")
      expect(result.structured_output).must_equal({sentiment: "positive", score: 0.9})
    end

    it "sets structured_output to nil when LLM returns invalid JSON" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        structured_output do
          required :sentiment, String
        end
      end

      agent = klass.new
      provider = agent.provider
      provider.stub_response("This is not JSON")

      result = agent.generate("Analyze sentiment")
      expect(result.structured_output).must_be_nil
    end

    it "preserves raw content when structured_output parsing fails" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        structured_output do
          required :sentiment, String
        end
      end

      agent = klass.new
      provider = agent.provider
      provider.stub_response("This is not JSON")

      result = agent.generate("Analyze sentiment")
      expect(result.content).must_equal "This is not JSON"
    end

    it "works with Params instance at class level" do
      params = Riffer::Params.new
      params.required(:sentiment, String)

      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        structured_output params
      end

      agent = klass.new
      provider = agent.provider
      provider.stub_response('{"sentiment":"positive"}')

      result = agent.generate("Analyze")
      expect(result.structured_output).must_equal({sentiment: "positive"})
    end

    it "returns nil structured_output when structured_output is not configured" do
      agent = agent_class.new
      result = agent.generate("Hello")
      expect(result.structured_output).must_be_nil
    end

    it "stores structured_output hash on the assistant message in agent.session.messages" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        structured_output do
          required :sentiment, String
        end
      end

      agent = klass.new
      provider = agent.provider
      provider.stub_response('{"sentiment":"positive"}')

      agent.generate("Analyze sentiment")
      # TODO: Replace with rfind when minimum Ruby is 4.0+
      last_assistant = agent.session.messages.reverse.find { |m| m.is_a?(Riffer::Messages::Assistant) } # rubocop:disable Style/ReverseFind
      expect(last_assistant.structured_output?).must_equal true
      expect(last_assistant.structured_output).must_equal({sentiment: "positive"})
    end

    it "makes structured_output available via on_message callback" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        structured_output do
          required :sentiment, String
        end
      end

      agent = klass.new
      provider = agent.provider
      provider.stub_response('{"sentiment":"positive"}')

      callback_msg = nil
      agent.session.on_message do |msg|
        callback_msg = msg if msg.is_a?(Riffer::Messages::Assistant)
      end
      agent.generate("Analyze sentiment")
      expect(callback_msg.structured_output?).must_equal true
      expect(callback_msg.structured_output).must_equal({sentiment: "positive"})
    end
  end

  describe "#stream with structured_output" do
    it "raises ArgumentError when class-level structured_output is configured" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        structured_output do
          required :sentiment, String
        end
      end

      agent = klass.new
      error = expect { agent.stream("Hello") }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Structured output is not supported with streaming/)
    end

    it "works normally without structured_output" do
      agent = agent_class.new
      result = agent.stream("Hello")
      expect(result).must_be_instance_of Enumerator
    end
  end

  describe "#generate with guardrails" do
    let(:transform_guardrail_class) do
      Class.new(Riffer::Guardrail) do
        def process_input(messages, context:)
          transform(messages.map { |m|
            case m
            when Riffer::Messages::User
              Riffer::Messages::User.new("[INPUT] #{m.content}")
            else
              m
            end
          })
        end

        def process_output(response, messages:, context:)
          transform(Riffer::Messages::Assistant.new("[OUTPUT] #{response.content}"))
        end
      end
    end

    let(:block_input_guardrail_class) do
      Class.new(Riffer::Guardrail) do
        def process_input(messages, context:)
          block("Input blocked", metadata: {reason: "test"})
        end
      end
    end

    let(:block_output_guardrail_class) do
      Class.new(Riffer::Guardrail) do
        def process_output(response, messages:, context:)
          block("Output blocked", metadata: {reason: "test"})
        end
      end
    end

    it "returns Response object" do
      result = agent_class.generate("Hello")
      expect(result).must_be_instance_of Riffer::Agent::Response
    end

    it "response is not blocked without guardrails" do
      result = agent_class.generate("Hello")
      expect(result.blocked?).must_equal false
    end

    it "response content is accessible" do
      result = agent_class.generate("Hello")
      expect(result.content).wont_be_empty
    end

    describe "with before guardrail that blocks" do
      let(:agent_with_blocking_input) do
        gr = block_input_guardrail_class
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
        end
        klass.guardrail(:before, with: gr)
        klass
      end

      it "returns blocked response" do
        result = agent_with_blocking_input.generate("Hello")
        expect(result.blocked?).must_equal true
      end

      it "has tripwire with reason" do
        result = agent_with_blocking_input.generate("Hello")
        expect(result.tripwire.reason).must_equal "Input blocked"
      end

      it "has tripwire with phase" do
        result = agent_with_blocking_input.generate("Hello")
        expect(result.tripwire.phase).must_equal :before
      end

      it "has tripwire with guardrail" do
        result = agent_with_blocking_input.generate("Hello")
        expect(result.tripwire.guardrail).must_equal block_input_guardrail_class
      end

      it "has tripwire with metadata" do
        result = agent_with_blocking_input.generate("Hello")
        expect(result.tripwire.metadata).must_equal({reason: "test"})
      end

      it "has empty content" do
        result = agent_with_blocking_input.generate("Hello")
        expect(result.content).must_equal ""
      end
    end

    describe "with after guardrail that blocks" do
      let(:agent_with_blocking_output) do
        gr = block_output_guardrail_class
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
        end
        klass.guardrail(:after, with: gr)
        klass
      end

      it "returns blocked response" do
        result = agent_with_blocking_output.generate("Hello")
        expect(result.blocked?).must_equal true
      end

      it "has tripwire with after phase" do
        result = agent_with_blocking_output.generate("Hello")
        expect(result.tripwire.phase).must_equal :after
      end

      it "has tripwire with reason" do
        result = agent_with_blocking_output.generate("Hello")
        expect(result.tripwire.reason).must_equal "Output blocked"
      end
    end

    describe "with transform guardrails" do
      let(:agent_with_transform) do
        gr = transform_guardrail_class
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
        end
        klass.guardrail(:around, with: gr)
        klass
      end

      it "transforms input messages" do
        agent = agent_with_transform.new
        agent.generate("Hello")
        user_message = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::User) }
        expect(user_message.content).must_equal "[INPUT] Hello"
      end

      it "transforms output response" do
        result = agent_with_transform.generate("Hello")
        expect(result.content).must_match(/\[OUTPUT\]/)
      end

      it "returns unblocked response" do
        result = agent_with_transform.generate("Hello")
        expect(result.blocked?).must_equal false
      end

      it "response is modified" do
        result = agent_with_transform.generate("Hello")
        expect(result.modified?).must_equal true
      end

      it "response has modifications with correct guardrail" do
        result = agent_with_transform.generate("Hello")
        guardrails = result.modifications.map(&:guardrail)
        expect(guardrails).must_include transform_guardrail_class
      end

      it "after phase modifications have remapped message indices" do
        result = agent_with_transform.generate("Hello")
        after_mods = result.modifications.select { |m| m.phase == :after }
        expect(after_mods).wont_be_empty
        after_mods.each { |m| expect(m.message_indices.first).must_be :>, 0 }
      end
    end

    describe "without guardrails" do
      it "response modifications is empty" do
        result = agent_class.generate("Hello")
        expect(result.modifications).must_be_empty
      end

      it "response is not modified" do
        result = agent_class.generate("Hello")
        expect(result.modified?).must_equal false
      end
    end
  end

  describe "#stream with guardrails" do
    let(:block_input_guardrail_class) do
      Class.new(Riffer::Guardrail) do
        def process_input(messages, context:)
          block("Input blocked")
        end
      end
    end

    let(:block_output_guardrail_class) do
      Class.new(Riffer::Guardrail) do
        def process_output(response, messages:, context:)
          block("Output blocked")
        end
      end
    end

    describe "with before guardrail that blocks" do
      let(:agent_with_blocking_input) do
        gr = block_input_guardrail_class
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
        end
        klass.guardrail(:before, with: gr)
        klass
      end

      it "yields tripwire event" do
        events = agent_with_blocking_input.stream("Hello").to_a
        tripwire_event = events.find { |e| e.is_a?(Riffer::StreamEvents::GuardrailTripwire) }
        expect(tripwire_event).wont_be_nil
      end

      it "tripwire event has reason" do
        events = agent_with_blocking_input.stream("Hello").to_a
        tripwire_event = events.find { |e| e.is_a?(Riffer::StreamEvents::GuardrailTripwire) }
        expect(tripwire_event.reason).must_equal "Input blocked"
      end

      it "tripwire event has before phase" do
        events = agent_with_blocking_input.stream("Hello").to_a
        tripwire_event = events.find { |e| e.is_a?(Riffer::StreamEvents::GuardrailTripwire) }
        expect(tripwire_event.phase).must_equal :before
      end
    end

    describe "with after guardrail that blocks" do
      let(:agent_with_blocking_output) do
        gr = block_output_guardrail_class
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
        end
        klass.guardrail(:after, with: gr)
        klass
      end

      it "yields tripwire event" do
        events = agent_with_blocking_output.stream("Hello").to_a
        tripwire_event = events.find { |e| e.is_a?(Riffer::StreamEvents::GuardrailTripwire) }
        expect(tripwire_event).wont_be_nil
      end

      it "tripwire event has after phase" do
        events = agent_with_blocking_output.stream("Hello").to_a
        tripwire_event = events.find { |e| e.is_a?(Riffer::StreamEvents::GuardrailTripwire) }
        expect(tripwire_event.phase).must_equal :after
      end

      it "still yields text events before blocking" do
        events = agent_with_blocking_output.stream("Hello").to_a
        text_events = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
        expect(text_events).wont_be_empty
      end
    end

    describe "with transform guardrails" do
      let(:transform_guardrail_class) do
        Class.new(Riffer::Guardrail) do
          def process_input(messages, context:)
            transform(messages.map { |m|
              case m
              when Riffer::Messages::User
                Riffer::Messages::User.new("[INPUT] #{m.content}")
              else
                m
              end
            })
          end
        end
      end

      let(:agent_with_stream_transform) do
        gr = transform_guardrail_class
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
        end
        klass.guardrail(:before, with: gr)
        klass
      end

      it "emits GuardrailModification events on transforms" do
        events = agent_with_stream_transform.stream("Hello").to_a
        mod_events = events.select { |e| e.is_a?(Riffer::StreamEvents::GuardrailModification) }
        expect(mod_events).wont_be_empty
      end

      it "GuardrailModification event has correct guardrail" do
        events = agent_with_stream_transform.stream("Hello").to_a
        mod_event = events.find { |e| e.is_a?(Riffer::StreamEvents::GuardrailModification) }
        expect(mod_event.guardrail).must_equal transform_guardrail_class
      end
    end
  end

  describe "token usage tracking with #generate" do
    let(:token_usage) { Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50) }

    it "tracks token usage from response" do
      agent = agent_class.new
      provider = agent.provider
      provider.stub_response("Hello!", token_usage: token_usage)
      agent.generate("Hi")
      expect(agent.context[:token_usage]).wont_be_nil
      expect(agent.context[:token_usage].input_tokens).must_equal 100
      expect(agent.context[:token_usage].output_tokens).must_equal 50
    end

    it "accumulates token usage across tool loops" do
      tool_class = Class.new(Riffer::Tool) do
        description "Test tool"
        def call(context:)
          text("done")
        end
      end.tap { |t| t.identifier("token_usage_test_tool") }

      tc = tool_class
      agent_with_tools = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tc]
      end

      agent = agent_with_tools.new
      provider = agent.provider
      token_usage1 = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      token_usage2 = Riffer::TokenUsage.new(input_tokens: 150, output_tokens: 75)
      provider.stub_response("", tool_calls: [{name: "token_usage_test_tool", arguments: "{}"}], token_usage: token_usage1)
      provider.stub_response("Done!", token_usage: token_usage2)

      agent.generate("Call tool")

      expect(agent.context[:token_usage].input_tokens).must_equal 250
      expect(agent.context[:token_usage].output_tokens).must_equal 125
    end

    it "does not track nil token usage" do
      agent = agent_class.new
      provider = agent.provider
      provider.stub_response("Hello!")
      agent.generate("Hi")
      expect(agent.context[:token_usage]).must_be_nil
    end

    it "attaches token usage to assistant messages" do
      agent = agent_class.new
      provider = agent.provider
      provider.stub_response("Hello!", token_usage: token_usage)
      agent.generate("Hi")
      assistant = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::Assistant) }
      expect(assistant.token_usage).must_equal token_usage
    end
  end

  describe "token usage tracking with #stream" do
    let(:token_usage) { Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50) }

    it "tracks token usage from TokenUsageDone event" do
      agent = agent_class.new
      provider = agent.provider
      provider.stub_response("Hello!", token_usage: token_usage)
      agent.stream("Hi").each { |_| }
      expect(agent.context[:token_usage]).wont_be_nil
      expect(agent.context[:token_usage].input_tokens).must_equal 100
      expect(agent.context[:token_usage].output_tokens).must_equal 50
    end

    it "yields TokenUsageDone event" do
      agent = agent_class.new
      provider = agent.provider
      provider.stub_response("Hello!", token_usage: token_usage)
      events = agent.stream("Hi").to_a
      token_usage_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }
      expect(token_usage_done).wont_be_nil
    end

    it "attaches token usage to assistant messages" do
      agent = agent_class.new
      provider = agent.provider
      provider.stub_response("Hello!", token_usage: token_usage)
      agent.stream("Hi").each { |_| }
      assistant = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::Assistant) }
      expect(assistant.token_usage).must_equal token_usage
    end

    it "accumulates token usage across tool loops" do
      tool_class = Class.new(Riffer::Tool) do
        description "Test tool"
        def call(context:)
          text("done")
        end
      end.tap { |t| t.identifier("stream_token_usage_test_tool") }

      tc = tool_class
      agent_with_tools = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tc]
      end

      agent = agent_with_tools.new
      provider = agent.provider
      token_usage1 = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      token_usage2 = Riffer::TokenUsage.new(input_tokens: 150, output_tokens: 75)
      provider.stub_response("", tool_calls: [{name: "stream_token_usage_test_tool", arguments: "{}"}], token_usage: token_usage1)
      provider.stub_response("Done!", token_usage: token_usage2)

      agent.stream("Call tool").each { |_| }

      expect(agent.context[:token_usage].input_tokens).must_equal 250
      expect(agent.context[:token_usage].output_tokens).must_equal 125
    end
  end

  describe "pending tool calls on fresh generate" do
    it "does not execute pending tool calls" do
      tool_class = Class.new(Riffer::Tool) do
        description "Simple tool"
        def call(context:)
          text("done")
        end
      end.tap { |t| t.identifier("fresh_generate_tool") }

      tc = tool_class
      custom_agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tc]
      end

      agent = custom_agent_class.new
      provider = agent.provider
      provider.stub_response("", tool_calls: [
        {name: "fresh_generate_tool", arguments: "{}"}
      ])
      provider.stub_response("Done!")

      result = agent.generate("Call tool")
      expect(result.interrupted?).must_equal false
      tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
      expect(tool_messages.length).must_equal 1
    end
  end

  describe "pending tool call resume with #stream" do
    it "resumes pending tools in streaming mode" do
      tool_class = Class.new(Riffer::Tool) do
        description "Simple tool"
        def call(context:)
          text("done")
        end
      end.tap { |t| t.identifier("stream_pending_tool") }

      tc = tool_class
      custom_agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tc]
      end

      agent = custom_agent_class.new
      provider = agent.provider
      provider.stub_response("", tool_calls: [
        {name: "stream_pending_tool", arguments: "{}"},
        {name: "stream_pending_tool", arguments: "{}"}
      ])
      provider.stub_response("Done!")

      tool_count = 0
      agent.session.on_message do |msg|
        if msg.is_a?(Riffer::Messages::Tool)
          tool_count += 1
          throw :riffer_interrupt if tool_count == 1
        end
      end

      events = agent.stream("Call tools").to_a
      interrupt_event = events.find { |e| e.is_a?(Riffer::StreamEvents::Interrupt) }
      expect(interrupt_event).wont_be_nil
      tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
      expect(tool_messages.length).must_equal 1

      events = agent.stream("Continue").to_a
      interrupt_event = events.find { |e| e.is_a?(Riffer::StreamEvents::Interrupt) }
      expect(interrupt_event).must_be_nil
      tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
      expect(tool_messages.length).must_equal 2
    end
  end

  describe "interrupt! with experimental_history_healing" do
    let(:tool_class) do
      Class.new(Riffer::Tool) do
        description "Slow tool"
        def call(context:)
          text("done")
        end
      end.tap { |t| t.identifier("interrupt_heal_tool") }
    end

    after { Riffer.config.experimental_history_healing = false }

    it "fills orphans and exposes healed_tool_call_ids when healing is on" do
      Riffer.config.experimental_history_healing = true
      tc = tool_class
      custom_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tc]
      end

      agent = custom_class.new
      provider = agent.provider
      provider.stub_response("", tool_calls: [
        {name: "interrupt_heal_tool", arguments: "{}"},
        {name: "interrupt_heal_tool", arguments: "{}"}
      ])

      agent.session.on_message do |msg|
        agent.interrupt!(:user_interrupt) if msg.is_a?(Riffer::Messages::Assistant) && !msg.tool_calls.empty?
      end

      result = agent.generate("Call tools")

      expect(result.interrupted?).must_equal true
      expect(result.healed_tool_call_ids.length).must_equal 2
      expect(agent.session.orphaned_tool_call_ids).must_equal []
      tools = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
      expect(tools.length).must_equal 2
      expect(tools.first.error_type).must_equal :interrupted
      expect(tools.first.content).must_equal "Tool call interrupted before completion."
    end

    it "leaves orphans in place when healing is off (default)" do
      tc = tool_class
      custom_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tc]
      end

      agent = custom_class.new
      provider = agent.provider
      provider.stub_response("", tool_calls: [{name: "interrupt_heal_tool", arguments: "{}"}])

      agent.session.on_message do |msg|
        agent.interrupt! if msg.is_a?(Riffer::Messages::Assistant) && !msg.tool_calls.empty?
      end

      result = agent.generate("Call tools")

      expect(result.interrupted?).must_equal true
      expect(result.healed_tool_call_ids).must_equal []
      expect(agent.session.orphaned_tool_call_ids.length).must_equal 1
    end

    it "does not fire on_message for placeholder tool messages" do
      Riffer.config.experimental_history_healing = true
      tc = tool_class
      custom_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tc]
      end

      agent = custom_class.new
      provider = agent.provider
      provider.stub_response("", tool_calls: [{name: "interrupt_heal_tool", arguments: "{}"}])

      seen = []
      agent.session.on_message do |msg|
        seen << msg
        agent.interrupt! if msg.is_a?(Riffer::Messages::Assistant) && !msg.tool_calls.empty?
      end

      agent.generate("Call tools")

      # The assistant message is observed, but the placeholder Tool result
      # is not — placeholders bypass on_message because they aren't
      # inference output.
      expect(seen.count { |m| m.is_a?(Riffer::Messages::Tool) }).must_equal 0
    end
  end

  describe "max_steps interrupt with experimental_history_healing" do
    let(:tool_class) do
      Class.new(Riffer::Tool) do
        description "Loop tool"
        def call(context:)
          text("ok")
        end
      end.tap { |t| t.identifier("max_steps_heal_tool") }
    end

    after { Riffer.config.experimental_history_healing = false }

    it "fills orphan tool_use with the placeholder when healing is on" do
      Riffer.config.experimental_history_healing = true
      tc = tool_class
      custom_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tc]
        max_steps 1
      end

      agent = custom_class.new
      provider = agent.provider
      provider.stub_response("", tool_calls: [{name: "max_steps_heal_tool", arguments: "{}"}])
      provider.stub_response("", tool_calls: [{name: "max_steps_heal_tool", arguments: "{}"}])

      result = agent.generate("Loop forever")

      expect(result.interrupted?).must_equal true
      expect(result.interrupt_reason).must_equal Riffer::Agent::INTERRUPT_MAX_STEPS
      expect(result.healed_tool_call_ids.length).must_equal 1
      expect(agent.session.orphaned_tool_call_ids).must_equal []
      synth = agent.session.messages.last
      expect(synth).must_be_kind_of Riffer::Messages::Tool
      expect(synth.error_type).must_equal :interrupted
    end

    it "leaves orphan tool_use when healing is off" do
      tc = tool_class
      custom_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tc]
        max_steps 1
      end

      agent = custom_class.new
      provider = agent.provider
      provider.stub_response("", tool_calls: [{name: "max_steps_heal_tool", arguments: "{}"}])
      provider.stub_response("", tool_calls: [{name: "max_steps_heal_tool", arguments: "{}"}])

      result = agent.generate("Loop forever")

      expect(result.interrupted?).must_equal true
      expect(result.interrupt_reason).must_equal Riffer::Agent::INTERRUPT_MAX_STEPS
      expect(result.healed_tool_call_ids).must_equal []
      expect(agent.session.orphaned_tool_call_ids.length).must_equal 1
    end
  end

  describe "seeded history with experimental_history_healing" do
    let(:custom_class) { Class.new(Riffer::Agent) { model "mock/riffer-1" } }

    after { Riffer.config.experimental_history_healing = false }

    it "passes seeded history through untouched when healing is off (default)" do
      tc = Riffer::Messages::Assistant::ToolCall.new(call_id: "c_orphan", name: "t", arguments: "{}")
      seeded = Riffer::Session.new(messages: [
        Riffer::Messages::User.new("hi"),
        Riffer::Messages::Tool.new("ghost", tool_call_id: "c_missing", name: "t"),
        Riffer::Messages::Assistant.new("", tool_calls: [tc]),
        Riffer::Messages::User.new("follow up"),
        Riffer::Messages::Assistant.new("ok")
      ])
      agent = custom_class.new(session: seeded)
      agent.provider.stub_response("Hello!")
      agent.generate

      assistant_with_orphan = agent.session.messages.find { |m|
        m.is_a?(Riffer::Messages::Assistant) && m.tool_calls.any? { |x| x.call_id == "c_orphan" }
      }
      refute_nil assistant_with_orphan
      parentless = agent.session.messages.find { |m|
        m.is_a?(Riffer::Messages::Tool) && m.tool_call_id == "c_missing"
      }
      refute_nil parentless
    end

    it "preserves a pending tool_use on the resume boundary even when healing is on" do
      Riffer.config.experimental_history_healing = true
      tc = Riffer::Messages::Assistant::ToolCall.new(call_id: "c_pending", name: "pending_seed_tool", arguments: "{}")
      seeded = Riffer::Session.new(messages: [
        Riffer::Messages::User.new("Call tool"),
        Riffer::Messages::Assistant.new("", tool_calls: [tc])
      ])
      tool = Class.new(Riffer::Tool) do
        description "Pending tool"
        def call(context:)
          text("done")
        end
      end.tap { |t| t.identifier("pending_seed_tool") }
      with_tools = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tool]
      end

      agent = with_tools.new(session: seeded)
      agent.provider.stub_response("All done!")
      result = agent.generate
      expect(result.interrupted?).must_equal false
    end
  end

  describe "tool calling" do
    let(:weather_tool_class) do
      Class.new(Riffer::Tool) do
        description "Gets the weather"

        params do
          required :city, String
        end

        def call(context:, city:)
          text("Weather in #{city}: 20 degrees")
        end
      end
    end

    let(:context_tool_class) do
      Class.new(Riffer::Tool) do
        description "Gets user info"

        params do
          required :field, String
        end

        def call(context:, field:)
          text(context[field.to_sym] || "unknown")
        end
      end
    end

    describe "#generate with tools" do
      it "adds tool message after executing tool call" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather in Toronto is nice!")

        agent.generate("What's the weather in Toronto?")

        tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.length).must_equal 1
      end

      it "includes tool result in tool message content" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather in Toronto is nice!")

        agent.generate("What's the weather in Toronto?")

        tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.first.content).must_equal "Weather in Toronto: 20 degrees"
      end

      it "returns final response after tool execution" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather in Toronto is nice!")

        result = agent.generate("What's the weather in Toronto?")

        expect(result.content).must_equal "The weather in Toronto is nice!"
      end

      it "passes context to tools" do
        tool_class = context_tool_class
        tool_class.identifier("context_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new(context: {user_name: "Alice"})
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "context_tool", arguments: '{"field":"user_name"}'}
        ])
        provider.stub_response("Your name is Alice!")

        agent.generate("Get my name")

        tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.first.content).must_equal "Alice"
      end

      it "returns error message for unknown tool" do
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools []
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "nonexistent_tool", arguments: "{}"}
        ])
        provider.stub_response("I couldn't find that tool.")

        agent.generate("Call nonexistent tool")

        tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.first.content).must_match(/Unknown tool/)
      end

      it "sets error attributes for unknown tool" do
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools []
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "nonexistent_tool", arguments: "{}"}
        ])
        provider.stub_response("I couldn't find that tool.")

        agent.generate("Call nonexistent tool")

        tool_message = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_message.error?).must_equal true
        expect(tool_message.error).must_equal "Unknown tool 'nonexistent_tool'"
        expect(tool_message.error_type).must_equal :unknown_tool
      end

      it "handles validation errors gracefully" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: "{}"}
        ])
        provider.stub_response("Sorry, I need a city.")

        agent.generate("What's the weather?")

        tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.first.content).must_match(/city is required/)
      end

      it "sets error attributes for validation errors" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: "{}"}
        ])
        provider.stub_response("Sorry, I need a city.")

        agent.generate("What's the weather?")

        tool_message = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_message.error?).must_equal true
        expect(tool_message.error_type).must_equal :validation_error
      end

      it "does not set error attributes for successful tool calls" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather in Toronto is nice!")

        agent.generate("What's the weather in Toronto?")

        tool_message = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_message.error?).must_equal false
        expect(tool_message.error).must_be_nil
        expect(tool_message.error_type).must_be_nil
      end

      it "passes tools to provider" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        agent.generate("Hello")

        expect(provider.calls.last[:tools]).wont_be_nil
      end

      it "passes correct number of tools to provider" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        agent.generate("Hello")

        expect(provider.calls.last[:tools].length).must_equal 1
      end
    end

    describe "#stream with tools" do
      it "yields tool call events" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather is nice!")

        events = agent.stream("What's the weather?").to_a

        tool_call_done_events = events.select { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
        expect(tool_call_done_events).wont_be_empty
      end

      it "adds tool messages during streaming" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather is nice!")

        agent.stream("What's the weather?").each { |_| }

        tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.length).must_equal 1
      end

      it "passes context in streaming mode" do
        tool_class = context_tool_class
        tool_class.identifier("context_tool")
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new(context: {user_id: "12345"})
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "context_tool", arguments: '{"field":"user_id"}'}
        ])
        provider.stub_response("Your ID is 12345!")

        agent.stream("Get my id").each { |_| }

        tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.first.content).must_equal "12345"
      end
    end

    describe "tool timeouts" do
      let(:slow_tool_class) do
        Class.new(Riffer::Tool) do
          description "A slow tool"
          timeout 0.01

          def call(context:)
            sleep 0.02
            text("done")
          end
        end
      end

      let(:fast_tool_class) do
        Class.new(Riffer::Tool) do
          description "A fast tool"

          def call(context:)
            text("fast result")
          end
        end
      end

      it "times out slow tools" do
        tool_class = slow_tool_class
        tool_class.identifier("slow_tool")

        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "slow_tool", arguments: "{}"}
        ])
        provider.stub_response("The tool timed out.")

        agent.generate("Run the slow tool")

        tool_message = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_message.error?).must_equal true
      end

      it "sets error content and error_type for timeout" do
        tool_class = slow_tool_class
        tool_class.identifier("slow_tool")

        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "slow_tool", arguments: "{}"}
        ])
        provider.stub_response("The tool timed out.")

        agent.generate("Run the slow tool")

        tool_message = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_message.content).must_match(/timed out/)
        expect(tool_message.error_type).must_equal :timeout_error
      end

      it "uses tool-level timeout in error message" do
        tool_class = slow_tool_class
        tool_class.identifier("slow_tool")

        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "slow_tool", arguments: "{}"}
        ])
        provider.stub_response("The tool timed out.")

        agent.generate("Run the slow tool")

        tool_message = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_message.error?).must_equal true
        expect(tool_message.error).must_match(/0\.01 seconds/)
      end

      it "fast tools do not timeout" do
        tool_class = fast_tool_class
        tool_class.identifier("fast_tool")

        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool_class]
        end

        agent = agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "fast_tool", arguments: "{}"}
        ])
        provider.stub_response("The tool ran successfully.")

        agent.generate("Run the fast tool")

        tool_message = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_message.error?).must_equal false
        expect(tool_message.content).must_equal "fast result"
      end
    end

    describe "with lambda-based tools" do
      it "evaluates lambda at resolution time" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        call_count = 0

        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools -> {
            call_count += 1
            [tool_class]
          }
        end

        agent = agent_class.new
        agent.generate("Hello")

        expect(call_count).must_be :>, 0
      end

      it "passes context to lambda when it accepts a parameter" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        received_context = nil

        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools ->(context) {
            received_context = context
            [tool_class]
          }
        end

        context = {user_id: 123, admin: true}
        agent = agent_class.new(context: context)
        agent.generate("Hello")

        expect(received_context[:user_id]).must_equal 123
        expect(received_context[:admin]).must_equal true
      end

      it "allows conditional tool resolution based on context" do
        admin_tool_class = Class.new(Riffer::Tool) do
          description "Admin only tool"
          params {}
          def call(context:)
            text("admin action")
          end
        end
        admin_tool_class.identifier("admin_tool")

        basic_tool_class = weather_tool_class
        basic_tool_class.identifier("weather_tool")

        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools ->(context) {
            tools = [basic_tool_class]
            tools << admin_tool_class if context&.dig(:admin)
            tools
          }
        end

        admin_agent = agent_class.new(context: {admin: true})
        provider = admin_agent.provider
        provider.stub_response("Done")
        admin_agent.generate("Hello")
        admin_tools = provider.calls.last[:tools]

        regular_agent = agent_class.new(context: {admin: false})
        provider2 = regular_agent.provider
        provider2.stub_response("Done")
        regular_agent.generate("Hello")
        regular_tools = provider2.calls.last[:tools]

        expect(admin_tools.length).must_equal 2
        expect(regular_tools.length).must_equal 1
      end

      it "evaluates lambda once per agent instance" do
        tool_class = weather_tool_class
        tool_class.identifier("weather_tool")
        call_values = []

        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools ->(context) {
            call_values << context[:call]
            [tool_class]
          }
        end

        agent_class.new(context: {call: 1}).generate("Hello")
        agent_class.new(context: {call: 2}).generate("Hello again")

        expect(call_values).must_equal [1, 2]
      end
    end
  end

  describe "#generate" do
    describe "with model_options" do
      let(:options_agent_class) do
        Class.new(Riffer::Agent) do
          identifier "options-agent"
          model "mock/riffer-1"
          instructions "You are a helpful assistant."
          model_options reasoning: "medium", temperature: 0.7
        end
      end

      it "passes model_options to provider" do
        agent = options_agent_class.new
        provider = agent.provider
        agent.generate("Hello")
        expect(provider.calls.last[:reasoning]).must_equal "medium"
      end

      it "passes all model_options to provider" do
        agent = options_agent_class.new
        provider = agent.provider
        agent.generate("Hello")
        expect(provider.calls.last[:temperature]).must_equal 0.7
      end
    end

    describe "with max_steps" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          description "Simple tool"
          def call(context:)
            text("done")
          end
        end.tap { |t| t.identifier("max_steps_tool") }
      end

      it "runs unlimited steps by default" do
        tc = tool_class
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          max_steps Float::INFINITY
          uses_tools [tc]
        end

        agent = custom_agent_class.new
        provider = agent.provider
        3.times { provider.stub_response("", tool_calls: [{name: "max_steps_tool", arguments: "{}"}]) }
        provider.stub_response("Final answer")

        agent.generate("Do stuff")
        expect(provider.calls.length).must_equal 4
      end

      it "limits LLM calls when max_steps is set" do
        tc = tool_class
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          max_steps 2
          uses_tools [tc]
        end

        agent = custom_agent_class.new
        provider = agent.provider
        3.times { provider.stub_response("", tool_calls: [{name: "max_steps_tool", arguments: "{}"}]) }
        provider.stub_response("Final answer")

        agent.generate("Do stuff")
        expect(provider.calls.length).must_equal 2
      end

      it "returns last assistant response content when limit is reached" do
        tc = tool_class
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          max_steps 1
          uses_tools [tc]
        end

        agent = custom_agent_class.new
        provider = agent.provider
        provider.stub_response("I need a tool", tool_calls: [{name: "max_steps_tool", arguments: "{}"}])

        result = agent.generate("Do stuff")
        expect(result.content).must_equal "I need a tool"
      end

      it "sets interrupted? to true when limit is reached" do
        tc = tool_class
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          max_steps 1
          uses_tools [tc]
        end

        agent = custom_agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [{name: "max_steps_tool", arguments: "{}"}])

        result = agent.generate("Do stuff")
        expect(result.interrupted?).must_equal true
      end

      it "sets interrupt_reason to :max_steps when limit is reached" do
        tc = tool_class
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          max_steps 1
          uses_tools [tc]
        end

        agent = custom_agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [{name: "max_steps_tool", arguments: "{}"}])

        result = agent.generate("Do stuff")
        expect(result.interrupt_reason).must_equal :max_steps
      end
    end

    describe "with mock provider" do
      it "returns a Response object" do
        agent = agent_class.new
        result = agent.generate("What is the weather?")
        expect(result).must_be_instance_of Riffer::Agent::Response
      end

      it "adds system message to messages when instructions are provided" do
        agent = agent_class.new
        agent.generate("Hello")
        system_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message).wont_be_nil
      end

      it "adds user message to messages" do
        agent = agent_class.new
        agent.generate("Hello")
        user_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::User) }
        expect(user_message).wont_be_nil
      end

      it "adds assistant message to messages" do
        agent = agent_class.new
        agent.generate("Hello")
        assistant_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::Assistant) }
        expect(assistant_message).wont_be_nil
      end

      it "returns the content of the final assistant message" do
        agent = agent_class.new
        result = agent.generate("Hello")
        expect(result.content).must_be_instance_of String
      end
    end

    describe "without instructions" do
      let(:no_instructions_agent_class) do
        Class.new(Riffer::Agent) do
          model "mock/gpt-4o"
        end
      end

      it "does not add system message" do
        agent = no_instructions_agent_class.new
        agent.generate("Hello")
        system_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message).must_be_nil
      end
    end

    describe "with dynamic instructions" do
      it "resolves the Proc at generate time" do
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          instructions -> { "Dynamic instructions" }
        end

        agent = klass.new
        agent.generate("Hello")
        system_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message.content).must_equal "Dynamic instructions"
      end

      it "passes context to the Proc" do
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          instructions ->(context) { "You are assisting #{context[:name]}" }
        end

        agent = klass.new(context: {name: "Jane"})
        agent.generate("Hello")
        system_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message.content).must_equal "You are assisting Jane"
      end

      it "passes an empty context Hash when not provided" do
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          instructions ->(context) { context[:name].nil? ? "No name" : "With name #{context[:name]}" }
        end

        agent = klass.new
        agent.generate("Hello")
        system_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message.content).must_equal "No name"
      end

      it "does not add system message when Proc returns nil" do
        returner = ->(_context) {}
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          instructions returner
        end

        agent = klass.new
        agent.generate("Hello")
        system_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message).must_be_nil
      end
    end

    describe "with invalid provider" do
      it "raises Riffer::ArgumentError at Agent.new when provider is not registered" do
        invalid_agent_class = Class.new(Riffer::Agent) do
          model "nonexistent/gpt-4"
        end

        error = expect { invalid_agent_class.new }.must_raise(Riffer::ArgumentError)
        expect(error.message).must_match(/Provider not found: nonexistent/)
      end
    end
  end

  describe "#stream" do
    describe "with model_options" do
      let(:options_agent_class) do
        Class.new(Riffer::Agent) do
          identifier "options-stream-agent"
          model "mock/riffer-1"
          instructions "You are a helpful assistant."
          model_options reasoning: "high", temperature: 0.5
        end
      end

      it "passes model_options to provider" do
        agent = options_agent_class.new
        provider = agent.provider
        agent.stream("Hello").each { |_| }
        expect(provider.calls.last[:reasoning]).must_equal "high"
      end

      it "passes all model_options to provider" do
        agent = options_agent_class.new
        provider = agent.provider
        agent.stream("Hello").each { |_| }
        expect(provider.calls.last[:temperature]).must_equal 0.5
      end
    end

    describe "with max_steps" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          description "Simple tool"
          def call(context:)
            text("done")
          end
        end.tap { |t| t.identifier("stream_max_steps_tool") }
      end

      it "limits LLM calls when max_steps is set" do
        tc = tool_class
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          max_steps 2
          uses_tools [tc]
        end

        agent = custom_agent_class.new
        provider = agent.provider
        3.times { provider.stub_response("", tool_calls: [{name: "stream_max_steps_tool", arguments: "{}"}]) }
        provider.stub_response("Final answer")

        agent.stream("Do stuff").each { |_| }
        expect(provider.calls.length).must_equal 2
      end

      it "emits Interrupt event with :max_steps reason when limit is reached" do
        tc = tool_class
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          max_steps 1
          uses_tools [tc]
        end

        agent = custom_agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [{name: "stream_max_steps_tool", arguments: "{}"}])

        events = agent.stream("Do stuff").to_a
        interrupt_event = events.find { |e| e.is_a?(Riffer::StreamEvents::Interrupt) }
        expect(interrupt_event).wont_be_nil
        expect(interrupt_event.reason).must_equal :max_steps
      end

      it "does not emit Interrupt event when limit is not reached" do
        tc = tool_class
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          max_steps 10
          uses_tools [tc]
        end

        agent = custom_agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [{name: "stream_max_steps_tool", arguments: "{}"}])
        provider.stub_response("Final answer")

        events = agent.stream("Do stuff").to_a
        interrupt_event = events.find { |e| e.is_a?(Riffer::StreamEvents::Interrupt) }
        expect(interrupt_event).must_be_nil
      end
    end

    describe "with mock provider" do
      it "returns an enumerator" do
        agent = agent_class.new
        result = agent.stream("What is the weather?")
        expect(result).must_be_instance_of Enumerator
      end

      it "yields stream events" do
        agent = agent_class.new
        chunks = []
        agent.stream("Hello").each do |chunk|
          chunks << chunk
        end
        expect(chunks).wont_be_empty
      end

      it "yields TextDelta events" do
        agent = agent_class.new
        events = agent.stream("Hello").to_a
        text_deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
        expect(text_deltas).wont_be_empty
      end

      it "yields a TextDone event" do
        agent = agent_class.new
        events = agent.stream("Hello").to_a
        text_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
        expect(text_done).wont_be_nil
      end

      it "adds system message to messages when instructions are provided" do
        agent = agent_class.new
        agent.stream("Hello").each { |_| }
        system_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message).wont_be_nil
      end

      it "adds user message to messages" do
        agent = agent_class.new
        agent.stream("Hello").each { |_| }
        user_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::User) }
        expect(user_message).wont_be_nil
      end

      it "adds assistant message to messages" do
        agent = agent_class.new
        agent.stream("Hello").each { |_| }
        assistant_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::Assistant) }
        expect(assistant_message).wont_be_nil
      end

      it "accumulates content from TextDelta events" do
        agent = agent_class.new
        agent.stream("Hello").each { |_| }
        assistant_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::Assistant) }
        expect(assistant_message.content).wont_be_empty
      end
    end

    describe "without instructions" do
      let(:no_instructions_agent_class) do
        Class.new(Riffer::Agent) do
          model "mock/gpt-4o"
        end
      end

      it "does not add system message" do
        agent = no_instructions_agent_class.new
        agent.stream("Hello").each { |_| }
        system_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message).must_be_nil
      end
    end

    describe "with dynamic instructions" do
      it "resolves the Proc with context" do
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          instructions ->(context) { "You are assisting #{context[:name]}" }
        end

        agent = klass.new(context: {name: "Jane"})
        agent.stream("Hello").each { |_| }
        system_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }
        expect(system_message.content).must_equal "You are assisting Jane"
      end
    end

    describe "with invalid provider" do
      it "raises Riffer::ArgumentError at Agent.new when provider is not registered" do
        invalid_agent_class = Class.new(Riffer::Agent) do
          model "nonexistent/gpt-4"
        end

        error = expect { invalid_agent_class.new }.must_raise(Riffer::ArgumentError)
        expect(error.message).must_match(/Provider not found: nonexistent/)
      end
    end
  end

  describe "#generate with files" do
    it "attaches files to user message" do
      agent = agent_class.new
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      agent.generate("Describe this", files: [file])
      user_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::User) }
      expect(user_message.files.length).must_equal 1
    end

    it "converts file hashes to FilePart objects" do
      agent = agent_class.new
      agent.generate("Describe this", files: [{data: "aGVsbG8=", media_type: "image/png"}])
      user_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::User) }
      expect(user_message.files.first).must_be_instance_of Riffer::FilePart
    end

    it "defaults to empty files when not provided" do
      agent = agent_class.new
      agent.generate("Hello")
      user_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::User) }
      expect(user_message.files).must_equal []
    end

    it "raises when files: is provided without a prompt" do
      agent = agent_class.new
      error = expect {
        agent.generate(nil, files: [{data: "aGVsbG8=", media_type: "image/png"}])
      }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/files: requires a prompt/)
    end
  end

  describe "#stream with files" do
    it "attaches files to user message" do
      agent = agent_class.new
      file = Riffer::FilePart.new(data: "aGVsbG8=", media_type: "image/png")
      agent.stream("Describe this", files: [file]).each { |_| }
      user_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::User) }
      expect(user_message.files.length).must_equal 1
    end

    it "converts file hashes to FilePart objects" do
      agent = agent_class.new
      agent.stream("Describe this", files: [{data: "aGVsbG8=", media_type: "image/png"}]).each { |_| }
      user_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::User) }
      expect(user_message.files.first).must_be_instance_of Riffer::FilePart
    end
  end

  describe "dynamic model selection" do
    it "resolves lambda for generate" do
      dynamic_agent_class = Class.new(Riffer::Agent) do
        model -> { "mock/riffer-1" }
      end

      result = dynamic_agent_class.generate("Hello")
      expect(result).must_be_instance_of Riffer::Agent::Response
    end

    it "resolves lambda for stream" do
      dynamic_agent_class = Class.new(Riffer::Agent) do
        model -> { "mock/riffer-1" }
      end

      events = dynamic_agent_class.stream("Hello").to_a
      expect(events).wont_be_empty
    end

    it "uses resolved model for provider lookup" do
      dynamic_agent_class = Class.new(Riffer::Agent) do
        model -> { "mock/riffer-1" }
      end

      agent = dynamic_agent_class.new
      provider = agent.provider
      agent.generate("Hello")
      expect(provider).must_be_instance_of Riffer::Providers::Mock
    end

    it "evaluates the model lambda once per agent instance" do
      call_count = 0
      dynamic_agent_class = Class.new(Riffer::Agent) do
        model -> {
          call_count += 1
          "mock/riffer-1"
        }
      end

      dynamic_agent_class.new
      dynamic_agent_class.new
      expect(call_count).must_equal 2
    end

    it "resolves model per agent instance based on context" do
      models_used = []
      dynamic_agent_class = Class.new(Riffer::Agent) do
        model ->(context) {
          model = context&.dig(:premium) ? "mock/riffer-premium" : "mock/riffer-basic"
          models_used << model
          model
        }
      end

      dynamic_agent_class.new(context: {premium: false}).generate("Hello")
      dynamic_agent_class.new(context: {premium: true}).generate("Hello")
      expect(models_used).must_equal ["mock/riffer-basic", "mock/riffer-premium"]
    end

    it "passes resolved model name to provider" do
      dynamic_agent_class = Class.new(Riffer::Agent) do
        model -> { "mock/my-model" }
      end

      agent = dynamic_agent_class.new
      provider = agent.provider
      agent.generate("Hello")
      expect(provider.calls.last[:model]).must_equal "my-model"
    end

    it "raises on invalid lambda return without slash" do
      dynamic_agent_class = Class.new(Riffer::Agent) do
        model -> { "invalid-format" }
      end

      error = expect { dynamic_agent_class.new }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Invalid model string: invalid-format/)
    end

    it "raises on nil lambda return" do
      value = nil
      dynamic_agent_class = Class.new(Riffer::Agent) do
        model -> { value }
      end

      error = expect { dynamic_agent_class.new }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/Invalid model string/)
    end

    it "static string still works" do
      static_agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
      end

      result = static_agent_class.generate("Hello")
      expect(result).must_be_instance_of Riffer::Agent::Response
    end
  end

  describe "message emit with #generate" do
    describe "on simple generate" do
      let(:emitted) { [] }
      let(:agent) do
        a = agent_class.new
        a.session.on_message { |msg| emitted << msg }
        a.generate("Hello")
        a
      end

      it "emits one message" do
        agent
        expect(emitted.length).must_equal 1
      end

      it "emits an assistant message" do
        agent
        expect(emitted.first).must_be_instance_of Riffer::Messages::Assistant
      end
    end

    describe "during tool use" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          description "Gets the weather"
          params do
            required :city, String
          end
          def call(context:, city:)
            text("Weather in #{city}: 20 degrees")
          end
        end.tap { |t| t.identifier("emit_weather_tool") }
      end

      let(:emitted) { [] }
      let(:agent) do
        tc = tool_class
        agent_with_tools = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tc]
        end

        a = agent_with_tools.new
        a.provider.stub_response("", tool_calls: [
          {name: "emit_weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        a.provider.stub_response("The weather is nice!")

        a.session.on_message { |msg| emitted << msg }
        a.generate("What's the weather?")
        a
      end

      it "emits three messages" do
        agent
        expect(emitted.length).must_equal 3
      end

      it "emits assistant with tool_calls first" do
        agent
        expect(emitted[0]).must_be_instance_of Riffer::Messages::Assistant
      end

      it "includes tool_calls in first assistant message" do
        agent
        expect(emitted[0].tool_calls).wont_be_empty
      end

      it "emits tool message second" do
        agent
        expect(emitted[1]).must_be_instance_of Riffer::Messages::Tool
      end

      it "emits final assistant message third" do
        agent
        expect(emitted[2]).must_be_instance_of Riffer::Messages::Assistant
      end
    end

    describe "when tool fails" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          description "A failing tool"
          params do
            required :value, String
          end
          def call(context:, value:)
            raise "Something went wrong"
          end
        end.tap { |t| t.identifier("failing_tool") }
      end

      let(:emitted) { [] }
      let(:tool_message) do
        tc = tool_class
        agent_with_tools = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tc]
        end

        agent = agent_with_tools.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "failing_tool", arguments: '{"value":"test"}'}
        ])
        provider.stub_response("Tool failed.")

        agent.session.on_message { |msg| emitted << msg }
        agent.generate("Call tool")

        emitted.find { |m| m.is_a?(Riffer::Messages::Tool) }
      end

      it "emits tool message with error flag" do
        expect(tool_message.error?).must_equal true
      end

      it "emits tool message with execution_error type" do
        expect(tool_message.error_type).must_equal :execution_error
      end
    end
  end

  describe "interruptible callbacks with #generate" do
    it "returns response with interrupted? true" do
      agent = agent_class.new
      agent.session.on_message { |_msg| throw :riffer_interrupt }
      result = agent.generate("Hello")
      expect(result.interrupted?).must_equal true
    end

    it "returns accumulated content" do
      agent = agent_class.new
      agent.session.on_message { |_msg| throw :riffer_interrupt }
      result = agent.generate("Hello")
      expect(result.content).must_be_instance_of String
    end

    it "captures interrupt reason" do
      agent = agent_class.new
      agent.session.on_message { |_msg| throw :riffer_interrupt, "needs approval" }
      result = agent.generate("Hello")
      expect(result.interrupted?).must_equal true
      expect(result.interrupt_reason).must_equal "needs approval"
    end

    it "returns nil interrupt_reason when no reason given" do
      agent = agent_class.new
      agent.session.on_message { |_msg| throw :riffer_interrupt }
      result = agent.generate("Hello")
      expect(result.interrupt_reason).must_be_nil
    end

    describe "throw during tool execution" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          description "Simple tool"
          def call(context:)
            text("done")
          end
        end.tap { |t| t.identifier("interrupt_partial_tool") }
      end

      it "stops tool execution on interrupt and resumes pending tools" do
        tc = tool_class
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tc]
        end

        agent = custom_agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "interrupt_partial_tool", arguments: "{}"},
          {name: "interrupt_partial_tool", arguments: "{}"}
        ])
        provider.stub_response("Done!")

        tool_count = 0
        agent.session.on_message do |msg|
          if msg.is_a?(Riffer::Messages::Tool)
            tool_count += 1
            throw :riffer_interrupt if tool_count == 1
          end
        end

        result = agent.generate("Call tools")

        expect(result.interrupted?).must_equal true
        tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.length).must_equal 1

        result = agent.generate("Continue")
        expect(result.interrupted?).must_equal false
        tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.length).must_equal 2
      end

      it "resumes all pending tools when interrupt fires on assistant callback" do
        tc = tool_class
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tc]
        end

        agent = custom_agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "interrupt_partial_tool", arguments: "{}"},
          {name: "interrupt_partial_tool", arguments: "{}"}
        ])
        provider.stub_response("Done!")

        interrupted_once = false
        agent.session.on_message do |msg|
          if msg.is_a?(Riffer::Messages::Assistant) && !interrupted_once
            interrupted_once = true
            throw :riffer_interrupt
          end
        end

        result = agent.generate("Call tools")

        expect(result.interrupted?).must_equal true
        tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.length).must_equal 0

        result = agent.generate("Continue")
        expect(result.interrupted?).must_equal false
        tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.length).must_equal 2
      end
    end

    describe "multiple callbacks where later one throws" do
      it "earlier callbacks still fire" do
        agent = agent_class.new
        first_called = false
        agent.session.on_message { |_msg| first_called = true }
        agent.session.on_message { |_msg| throw :riffer_interrupt }
        agent.generate("Hello")
        expect(first_called).must_equal true
      end
    end

    describe "#interrupt!" do
      it "interrupts the agent loop" do
        agent = agent_class.new
        agent.session.on_message { |_msg| agent.interrupt! }
        result = agent.generate("Hello")
        expect(result.interrupted?).must_equal true
      end

      it "passes reason to interrupt_reason" do
        agent = agent_class.new
        agent.session.on_message { |_msg| agent.interrupt!(:needs_approval) }
        result = agent.generate("Hello")
        expect(result.interrupt_reason).must_equal :needs_approval
      end

      it "defaults reason to nil" do
        agent = agent_class.new
        agent.session.on_message { |_msg| agent.interrupt! }
        result = agent.generate("Hello")
        expect(result.interrupt_reason).must_be_nil
      end
    end
  end

  describe "resume via generate" do
    it "re-enters loop without prior interruption" do
      agent = agent_class.new
      agent.generate("Hello")
      result = agent.generate("Continue")
      expect(result).must_be_instance_of Riffer::Agent::Response
      expect(result.interrupted?).must_equal false
    end

    it "returns a Response" do
      agent = agent_class.new
      interrupted_once = false
      agent.session.on_message do |_msg|
        unless interrupted_once
          interrupted_once = true
          throw :riffer_interrupt
        end
      end
      agent.generate("Hello")
      result = agent.generate("Continue")
      expect(result).must_be_instance_of Riffer::Agent::Response
    end

    it "returns non-interrupted response on successful resume" do
      agent = agent_class.new
      interrupted_once = false
      agent.session.on_message do |_msg|
        unless interrupted_once
          interrupted_once = true
          throw :riffer_interrupt
        end
      end
      agent.generate("Hello")
      result = agent.generate("Continue")
      expect(result.interrupted?).must_equal false
    end

    it "returns nil interrupt_reason on successful resume" do
      agent = agent_class.new
      interrupted_once = false
      agent.session.on_message do |_msg|
        unless interrupted_once
          interrupted_once = true
          throw :riffer_interrupt, "needs approval"
        end
      end
      agent.generate("Hello")
      result = agent.generate("Continue")
      expect(result.interrupt_reason).must_be_nil
    end

    it "preserves messages from original generate" do
      agent = agent_class.new
      interrupted_once = false
      agent.session.on_message do |_msg|
        unless interrupted_once
          interrupted_once = true
          throw :riffer_interrupt
        end
      end
      agent.generate("Hello")
      messages_before = agent.session.messages.length
      agent.generate("Continue")
      expect(agent.session.messages.length).must_be :>, messages_before
    end

    it "does not duplicate system message" do
      agent = agent_class.new
      interrupted_once = false
      agent.session.on_message do |_msg|
        unless interrupted_once
          interrupted_once = true
          throw :riffer_interrupt
        end
      end
      agent.generate("Hello")
      agent.generate("Continue")
      system_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::System) }
      expect(system_messages.length).must_equal 1
    end

    describe "with tools" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          description "Gets the weather"
          params do
            required :city, String
          end
          def call(context:, city:)
            text("Weather in #{city}: 20 degrees")
          end
        end.tap { |t| t.identifier("resume_weather_tool") }
      end

      it "completes tool loop after resume" do
        tc = tool_class
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tc]
        end

        agent = custom_agent_class.new
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "resume_weather_tool", arguments: '{"city":"Toronto"}'}
        ])
        provider.stub_response("The weather is nice!")

        interrupted_once = false
        agent.session.on_message do |msg|
          if msg.is_a?(Riffer::Messages::Tool) && !interrupted_once
            interrupted_once = true
            throw :riffer_interrupt
          end
        end

        result = agent.generate("What's the weather?")
        expect(result.interrupted?).must_equal true

        result = agent.generate("Continue")
        expect(result.interrupted?).must_equal false
        expect(result.content).must_equal "The weather is nice!"
      end
    end

    describe "with a seeded session" do
      it "resumes from a session constructed with persisted messages" do
        messages = [
          Riffer::Messages::System.new("You are a helpful assistant."),
          Riffer::Messages::User.new("Hello"),
          Riffer::Messages::Assistant.new("Hi there!")
        ]
        agent = agent_class.new(session: Riffer::Session.new(messages: messages))
        result = agent.generate
        expect(result).must_be_instance_of Riffer::Agent::Response
      end

      it "runs the loop without a prompt when the session already has the last user message" do
        agent = agent_class.new(session: Riffer::Session.new(messages: [Riffer::Messages::User.new("Hello")]))
        result = agent.generate
        expect(result.interrupted?).must_equal false
      end

      it "accepts a new prompt to continue the seeded conversation" do
        agent = agent_class.new(session: Riffer::Session.new(messages: [
          Riffer::Messages::User.new("Hi"),
          Riffer::Messages::Assistant.new("Hello!")
        ]))
        agent.generate("How are you?")
        user_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::User) }
        expect(user_messages.length).must_equal 2
        expect(user_messages.last.content).must_equal "How are you?"
      end

      it "uses init context for tool execution" do
        context_tool = Class.new(Riffer::Tool) do
          description "Gets user info"
          params do
            required :field, String
          end
          def call(context:, field:)
            text(context[field.to_sym] || "unknown")
          end
        end.tap { |t| t.identifier("resume_context_tool") }

        tc = context_tool
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tc]
        end

        session = Riffer::Session.new(messages: [Riffer::Messages::User.new("Get my name")])
        agent = custom_agent_class.new(session: session, context: {user_name: "Alice"})
        provider = agent.provider
        provider.stub_response("", tool_calls: [
          {name: "resume_context_tool", arguments: '{"field":"user_name"}'}
        ])
        provider.stub_response("Your name is Alice!")

        agent.generate

        tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.first.content).must_equal "Alice"
      end

      it "does not prepend the agent's configured instructions" do
        messages = [
          Riffer::Messages::System.new("Custom instructions."),
          Riffer::Messages::User.new("Hello")
        ]
        agent = agent_class.new(session: Riffer::Session.new(messages: messages))
        agent.generate
        system_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::System) }
        expect(system_messages.length).must_equal 1
        expect(system_messages.first.content).must_equal "Custom instructions."
      end

      it "executes pending tool calls left by a prior interrupt" do
        tc = Class.new(Riffer::Tool) do
          description "Simple tool"
          def call(context:)
            text("done")
          end
        end.tap { |t| t.identifier("cross_process_pending_tool") }

        tool = tc
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tool]
        end

        messages = [
          Riffer::Messages::User.new("Call tool"),
          Riffer::Messages::Assistant.new("", tool_calls: [
            Riffer::Messages::Assistant::ToolCall.new(call_id: "c_1", name: "cross_process_pending_tool", arguments: "{}")
          ])
        ]
        agent = custom_agent_class.new(session: Riffer::Session.new(messages: messages))
        provider = agent.provider
        provider.stub_response("All done!")

        result = agent.generate
        expect(result.interrupted?).must_equal false

        tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
        expect(tool_messages.length).must_equal 1
        expect(tool_messages.first.content).must_equal "done"
      end

      it "defaults context to a Hash with nil :skills when not provided" do
        agent = agent_class.new(session: Riffer::Session.new(messages: [Riffer::Messages::User.new("Hello")]))
        expect(agent.context).must_equal({skills: nil})
      end
    end

    describe "auto-derived step offset" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          description "Simple tool"
          def call(context:)
            text("done")
          end
        end.tap { |t| t.identifier("resume_step_tool") }
      end

      it "enforces max_steps across sessions" do
        tc = tool_class
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          max_steps 3
          uses_tools [tc]
        end

        agent = custom_agent_class.new
        provider = agent.provider
        3.times { provider.stub_response("", tool_calls: [{name: "resume_step_tool", arguments: "{}"}]) }

        # First generate: runs 2 steps then gets interrupted by callback
        interrupted_once = false
        agent.session.on_message do |msg|
          if msg.is_a?(Riffer::Messages::Tool) && !interrupted_once
            interrupted_once = true
            throw :riffer_interrupt
          end
        end

        result = agent.generate("Do stuff")
        expect(result.interrupted?).must_equal true

        # Resume via generate with array: step offset is auto-derived from assistant messages
        result = agent.generate("Continue")
        expect(result.interrupted?).must_equal true
        expect(result.interrupt_reason).must_equal :max_steps
      end

      it "enforces max_steps on cross-process resume via message counting" do
        tc = tool_class
        custom_agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          max_steps 4
          uses_tools [tc]
        end

        seeded = Riffer::Session.new(messages: [
          Riffer::Messages::User.new("Original prompt"),
          Riffer::Messages::Assistant.new("Step 1", tool_calls: []),
          Riffer::Messages::Assistant.new("Step 2", tool_calls: []),
          Riffer::Messages::Assistant.new("Step 3", tool_calls: []),
          Riffer::Messages::User.new("Continue")
        ])
        agent = custom_agent_class.new(session: seeded)
        provider = agent.provider
        # Only 1 more step fits before max_steps (3 prior + 1 = 4)
        provider.stub_response("", tool_calls: [{name: "resume_step_tool", arguments: "{}"}])

        result = agent.generate
        expect(result.interrupted?).must_equal true
        expect(result.interrupt_reason).must_equal :max_steps
      end
    end

    describe "with structured_output" do
      it "returns parsed structured_output on in-memory resume" do
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          structured_output do
            required :sentiment, String
          end
        end

        agent = klass.new
        provider = agent.provider
        provider.stub_response('{"sentiment":"positive"}')

        interrupted_once = false
        agent.session.on_message do |_msg|
          unless interrupted_once
            interrupted_once = true
            throw :riffer_interrupt
          end
        end

        agent.generate("Analyze sentiment")

        provider.stub_response('{"sentiment":"negative"}')
        result = agent.generate("Continue")
        expect(result.structured_output).must_equal({sentiment: "negative"})
      end

      it "returns parsed structured_output on cross-process resume" do
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          structured_output do
            required :sentiment, String
          end
        end

        session = Riffer::Session.new(messages: [Riffer::Messages::User.new("Analyze sentiment")])
        agent = klass.new(session: session)
        provider = agent.provider
        provider.stub_response('{"sentiment":"positive"}')

        result = agent.generate
        expect(result.structured_output).must_equal({sentiment: "positive"})
      end
    end
  end

  describe "resume via stream" do
    it "re-enters loop without prior interruption" do
      agent = agent_class.new
      agent.generate("Hello")
      events = agent.stream("Continue").to_a
      text_events = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
      expect(text_events).wont_be_empty
    end

    it "returns an Enumerator" do
      agent = agent_class.new
      interrupted_once = false
      agent.session.on_message do |_msg|
        unless interrupted_once
          interrupted_once = true
          throw :riffer_interrupt
        end
      end
      agent.generate("Hello")
      result = agent.stream("Continue")
      expect(result).must_be_instance_of Enumerator
    end

    it "yields stream events on in-memory resume" do
      agent = agent_class.new
      interrupted_once = false
      agent.session.on_message do |_msg|
        unless interrupted_once
          interrupted_once = true
          throw :riffer_interrupt
        end
      end
      agent.generate("Hello")
      events = agent.stream("Continue").to_a
      text_events = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
      expect(text_events).wont_be_empty
    end

    it "does not yield Interrupt event on successful resume" do
      agent = agent_class.new
      interrupted_once = false
      agent.session.on_message do |_msg|
        unless interrupted_once
          interrupted_once = true
          throw :riffer_interrupt
        end
      end
      agent.generate("Hello")
      events = agent.stream("Continue").to_a
      interrupt_event = events.find { |e| e.is_a?(Riffer::StreamEvents::Interrupt) }
      expect(interrupt_event).must_be_nil
    end

    describe "with a seeded session" do
      it "resumes from a session constructed with persisted messages" do
        session = Riffer::Session.new(messages: [
          Riffer::Messages::System.new("You are a helpful assistant."),
          Riffer::Messages::User.new("Hello")
        ])
        agent = agent_class.new(session: session)
        events = agent.stream.to_a
        text_events = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
        expect(text_events).wont_be_empty
      end

      it "runs the stream loop without a prompt when the session already has the last user message" do
        session = Riffer::Session.new(messages: [Riffer::Messages::User.new("Hello")])
        agent = agent_class.new(session: session)
        events = agent.stream.to_a
        interrupt_event = events.find { |e| e.is_a?(Riffer::StreamEvents::Interrupt) }
        expect(interrupt_event).must_be_nil
      end
    end
  end

  describe "multi-turn string continuation" do
    it "continues conversation when calling generate with a string on an agent with existing messages" do
      agent = agent_class.new
      agent.generate("Hello")
      messages_before = agent.session.messages.length

      result = agent.generate("Follow up")
      expect(result).must_be_instance_of Riffer::Agent::Response
      expect(agent.session.messages.length).must_be :>, messages_before
    end

    it "does not duplicate system messages on continuation" do
      agent = agent_class.new
      agent.generate("Hello")
      agent.generate("Follow up")
      system_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::System) }
      expect(system_messages.length).must_equal 1
    end

    it "appends new user message to existing history" do
      agent = agent_class.new
      agent.generate("Hello")
      agent.generate("Follow up")
      user_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::User) }
      expect(user_messages.length).must_equal 2
      expect(user_messages.last.content).must_equal "Follow up"
    end

    it "resumes after interrupt with a new user message" do
      agent = agent_class.new
      interrupted_once = false
      agent.session.on_message do |_msg|
        unless interrupted_once
          interrupted_once = true
          throw :riffer_interrupt
        end
      end

      result = agent.generate("Hello")
      expect(result.interrupted?).must_equal true

      result = agent.generate("Continue please")
      expect(result.interrupted?).must_equal false
      user_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::User) }
      expect(user_messages.length).must_equal 2
    end

    it "executes pending tool calls on string continuation" do
      tc = Class.new(Riffer::Tool) do
        description "Simple tool"
        def call(context:)
          text("done")
        end
      end.tap { |t| t.identifier("continuation_pending_tool") }

      tool = tc
      custom_agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tool]
      end

      agent = custom_agent_class.new
      provider = agent.provider
      provider.stub_response("", tool_calls: [
        {name: "continuation_pending_tool", arguments: "{}"},
        {name: "continuation_pending_tool", arguments: "{}"}
      ])
      provider.stub_response("Done!")

      tool_count = 0
      agent.session.on_message do |msg|
        if msg.is_a?(Riffer::Messages::Tool)
          tool_count += 1
          throw :riffer_interrupt if tool_count == 1
        end
      end

      result = agent.generate("Call tools")
      expect(result.interrupted?).must_equal true
      tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
      expect(tool_messages.length).must_equal 1

      result = agent.generate("Go ahead")
      expect(result.interrupted?).must_equal false
      tool_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
      expect(tool_messages.length).must_equal 2
    end

    it "enforces max_steps across continuations" do
      tc = Class.new(Riffer::Tool) do
        description "Simple tool"
        def call(context:)
          text("done")
        end
      end.tap { |t| t.identifier("continuation_step_tool") }

      tool = tc
      custom_agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        max_steps 3
        uses_tools [tool]
      end

      agent = custom_agent_class.new
      provider = agent.provider
      3.times { provider.stub_response("", tool_calls: [{name: "continuation_step_tool", arguments: "{}"}]) }

      interrupted_once = false
      agent.session.on_message do |msg|
        if msg.is_a?(Riffer::Messages::Tool) && !interrupted_once
          interrupted_once = true
          throw :riffer_interrupt
        end
      end

      result = agent.generate("Do stuff")
      expect(result.interrupted?).must_equal true

      result = agent.generate("Continue")
      expect(result.interrupted?).must_equal true
      expect(result.interrupt_reason).must_equal :max_steps
    end

    it "continues conversation with stream" do
      agent = agent_class.new
      agent.generate("Hello")

      events = agent.stream("Follow up").to_a
      text_events = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
      expect(text_events).wont_be_empty

      user_messages = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::User) }
      expect(user_messages.length).must_equal 2
    end
  end

  describe "interruptible callbacks with #stream" do
    it "yields Interrupt event" do
      agent = agent_class.new
      agent.session.on_message { |_msg| throw :riffer_interrupt }
      events = agent.stream("Hello").to_a
      interrupt_event = events.find { |e| e.is_a?(Riffer::StreamEvents::Interrupt) }
      expect(interrupt_event).wont_be_nil
    end

    it "yields Interrupt event with reason" do
      agent = agent_class.new
      agent.session.on_message { |_msg| throw :riffer_interrupt, "budget exceeded" }
      events = agent.stream("Hello").to_a
      interrupt_event = events.find { |e| e.is_a?(Riffer::StreamEvents::Interrupt) }
      expect(interrupt_event.reason).must_equal "budget exceeded"
    end

    it "yields Interrupt event with nil reason when none given" do
      agent = agent_class.new
      agent.session.on_message { |_msg| throw :riffer_interrupt }
      events = agent.stream("Hello").to_a
      interrupt_event = events.find { |e| e.is_a?(Riffer::StreamEvents::Interrupt) }
      expect(interrupt_event.reason).must_be_nil
    end
  end

  describe "message emit with #stream" do
    describe "on simple stream" do
      let(:emitted) { [] }
      let(:agent) do
        a = agent_class.new
        a.session.on_message { |msg| emitted << msg }
        a.stream("Hello").each { |_| }
        a
      end

      it "emits one message" do
        agent
        expect(emitted.length).must_equal 1
      end

      it "emits an assistant message" do
        agent
        expect(emitted.first).must_be_instance_of Riffer::Messages::Assistant
      end
    end

    describe "during tool calling loop" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          description "Gets the weather"
          params do
            required :city, String
          end
          def call(context:, city:)
            text("Weather in #{city}: 20 degrees")
          end
        end.tap { |t| t.identifier("stream_emit_weather_tool") }
      end

      let(:emitted) { [] }
      let(:agent) do
        tc = tool_class
        agent_with_tools = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          uses_tools [tc]
        end

        a = agent_with_tools.new
        a.provider.stub_response("", tool_calls: [
          {name: "stream_emit_weather_tool", arguments: '{"city":"Tokyo"}'}
        ])
        a.provider.stub_response("The weather is nice!")

        a.session.on_message { |msg| emitted << msg }
        a.stream("What's the weather?").each { |_| }
        a
      end

      it "emits three messages" do
        agent
        expect(emitted.length).must_equal 3
      end

      it "emits assistant message first" do
        agent
        expect(emitted[0]).must_be_instance_of Riffer::Messages::Assistant
      end

      it "emits tool message second" do
        agent
        expect(emitted[1]).must_be_instance_of Riffer::Messages::Tool
      end

      it "emits final assistant message third" do
        agent
        expect(emitted[2]).must_be_instance_of Riffer::Messages::Assistant
      end
    end
  end
end
