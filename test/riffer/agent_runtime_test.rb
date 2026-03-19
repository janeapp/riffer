# frozen_string_literal: true

require "test_helper"

describe Riffer::AgentRuntime do
  let(:subagent_class) do
    Class.new(Riffer::Agent) do
      identifier "sub-agent"
      model "mock/riffer-1"
      description "A helpful subagent"
      instructions "You are a helpful subagent."
    end
  end

  let(:agents) { {"agent__sub-agent" => subagent_class} }
  let(:context) { nil }

  def make_tool_call(name:, arguments:, id: "call_1")
    Riffer::Messages::Assistant::ToolCall.new(
      id: id,
      call_id: "call_id_#{id}",
      name: name,
      arguments: arguments
    )
  end

  def execute_single(runtime, tool_call, agents:, context:)
    results = runtime.execute([tool_call], agents: agents, context: context)
    results[0][1]
  end

  describe "#initialize" do
    it "raises NotImplementedError when instantiated directly" do
      expect {
        Riffer::AgentRuntime.new(runner: Riffer::Runner::Sequential.new)
      }.must_raise NotImplementedError
    end
  end

  describe "#execute" do
    it "dispatches to correct agent and returns response" do
      provider = Riffer::Providers::Mock.new
      provider.stub_response("Research result")
      subagent_class.define_method(:provider_instance) { provider }

      runtime = Riffer::AgentRuntime::Inline.new
      tool_call = make_tool_call(name: "agent__sub-agent", arguments: '{"message":"Research AI"}')

      result = execute_single(runtime, tool_call, agents: agents, context: context)

      expect(result).must_be_instance_of Riffer::Tools::Response
      expect(result.content).must_equal "Research result"
      expect(result.success?).must_equal true
    end

    it "returns error response for unknown agent" do
      runtime = Riffer::AgentRuntime::Inline.new
      tool_call = make_tool_call(name: "agent__nonexistent", arguments: '{"message":"hello"}')

      result = execute_single(runtime, tool_call, agents: agents, context: context)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :unknown_agent
      expect(result.content).must_match(/Unknown agent/)
    end

    it "returns error response for RuntimeError" do
      error_agent = Class.new(Riffer::Agent) do
        identifier "error-agent"
        model "mock/riffer-1"
        description "An agent that errors"

        define_method(:generate) do |*, **|
          raise "Something went wrong"
        end
      end

      runtime = Riffer::AgentRuntime::Inline.new
      tool_call = make_tool_call(name: "agent__error-agent", arguments: '{"message":"hello"}')

      result = execute_single(runtime, tool_call, agents: {"agent__error-agent" => error_agent}, context: context)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :execution_error
      expect(result.content).must_match(/Something went wrong/)
    end

    it "handles interrupted agent response" do
      interrupted_agent = Class.new(Riffer::Agent) do
        identifier "interrupted-agent"
        model "mock/riffer-1"
        description "An agent that gets interrupted"
      end

      provider = Riffer::Providers::Mock.new
      provider.stub_response("Partial result", tool_calls: [{name: "some_tool", arguments: "{}"}])
      provider.stub_response("Never reached")
      interrupted_agent.define_method(:provider_instance) { provider }
      interrupted_agent.max_steps 1

      runtime = Riffer::AgentRuntime::Inline.new
      tool_call = make_tool_call(name: "agent__interrupted-agent", arguments: '{"message":"do something"}')

      result = execute_single(runtime, tool_call, agents: {"agent__interrupted-agent" => interrupted_agent}, context: context)

      expect(result.success?).must_equal true
      expect(result.content).must_match(/interrupted/)
    end

    it "returns [tool_call, response] pairs in order" do
      provider = Riffer::Providers::Mock.new
      provider.stub_response("Result 1")
      provider.stub_response("Result 2")
      subagent_class.define_method(:provider_instance) { provider }

      runtime = Riffer::AgentRuntime::Inline.new
      tc1 = make_tool_call(name: "agent__sub-agent", arguments: '{"message":"first"}', id: "1")
      tc2 = make_tool_call(name: "agent__sub-agent", arguments: '{"message":"second"}', id: "2")

      results = runtime.execute([tc1, tc2], agents: agents, context: context)

      expect(results.length).must_equal 2
      expect(results[0][0]).must_equal tc1
      expect(results[0][1].content).must_equal "Result 1"
      expect(results[1][0]).must_equal tc2
      expect(results[1][1].content).must_equal "Result 2"
    end

    it "detects circular agent delegation" do
      agent_b = Class.new(Riffer::Agent) do
        identifier "agent-b"
        model "mock/riffer-1"
        description "Agent B"
      end

      runtime = Riffer::AgentRuntime::Inline.new
      tool_call = make_tool_call(name: "agent__agent-b", arguments: '{"message":"hello"}')

      # Simulate agent-b already being in the call stack
      context_with_stack = {_agent_stack: [agent_b]}

      result = execute_single(runtime, tool_call, agents: {"agent__agent-b" => agent_b}, context: context_with_stack)

      expect(result.error?).must_equal true
      expect(result.error_type).must_equal :circular_delegation
      expect(result.content).must_match(/Circular agent delegation detected/)
    end

    it "passes context to subagent" do
      received_context = nil
      ctx_agent = Class.new(Riffer::Agent) do
        identifier "ctx-agent"
        model "mock/riffer-1"
        description "Context capturing agent"
      end

      provider = Riffer::Providers::Mock.new
      provider.stub_response("Done")
      ctx_agent.define_method(:provider_instance) { provider }

      original_generate = ctx_agent.instance_method(:generate)
      ctx_agent.define_method(:generate) do |prompt, **kwargs|
        received_context = kwargs[:context]
        original_generate.bind_call(self, prompt, **kwargs)
      end

      runtime = Riffer::AgentRuntime::Inline.new
      tool_call = make_tool_call(name: "agent__ctx-agent", arguments: '{"message":"test"}')
      test_context = {user_id: 42}

      runtime.execute([tool_call], agents: {"agent__ctx-agent" => ctx_agent}, context: test_context)

      expect(received_context).must_equal test_context.merge(_agent_stack: [ctx_agent])
    end
  end

  describe "#around_agent_call" do
    it "yields by default" do
      provider = Riffer::Providers::Mock.new
      provider.stub_response("Result")
      subagent_class.define_method(:provider_instance) { provider }

      runtime = Riffer::AgentRuntime::Inline.new
      tool_call = make_tool_call(name: "agent__sub-agent", arguments: '{"message":"test"}')

      results = runtime.execute([tool_call], agents: agents, context: context)

      expect(results[0][1].content).must_equal "Result"
    end

    it "can be overridden in a subclass" do
      log = []
      runtime_class = Class.new(Riffer::AgentRuntime::Inline) do
        define_method(:around_agent_call) do |tool_call, context:, &block|
          log << "before:#{tool_call.name}"
          result = block.call
          log << "after:#{tool_call.name}"
          result
        end
      end

      provider = Riffer::Providers::Mock.new
      provider.stub_response("Result")
      subagent_class.define_method(:provider_instance) { provider }

      tool_call = make_tool_call(name: "agent__sub-agent", arguments: '{"message":"test"}')
      runtime_class.new.execute([tool_call], agents: agents, context: context)

      expect(log).must_equal ["before:agent__sub-agent", "after:agent__sub-agent"]
    end
  end
end

describe Riffer::AgentRuntime::Inline do
  it "behaves identically to base" do
    runtime = Riffer::AgentRuntime::Inline.new
    expect(runtime).must_be_kind_of Riffer::AgentRuntime
  end
end

describe Riffer::AgentRuntime::Threaded do
  it "executes agent calls in parallel" do
    thread_ids = Mutex.new
    seen = []

    parallel_agent = Class.new(Riffer::Agent) do
      identifier "parallel-agent"
      model "mock/riffer-1"
      description "Parallel agent"
    end

    parallel_agent.define_method(:generate) do |prompt, **kwargs|
      thread_ids.synchronize { seen << Thread.current.object_id }
      sleep 0.01
      Riffer::Agent::Response.new("done")
    end

    runtime = Riffer::AgentRuntime::Threaded.new(max_concurrency: 3)
    tool_calls = 3.times.map do |i|
      Riffer::Messages::Assistant::ToolCall.new(
        id: i.to_s, call_id: "cid_#{i}", name: "agent__parallel-agent", arguments: '{"message":"test"}'
      )
    end

    results = runtime.execute(tool_calls, agents: {"agent__parallel-agent" => parallel_agent}, context: nil)

    expect(results.length).must_equal 3
    expect(seen.uniq.length).must_be :>, 1
  end
end
