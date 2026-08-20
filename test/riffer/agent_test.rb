# frozen_string_literal: true

require "test_helper"

describe Riffer::Agent do
  let(:agent_class) do
    Class.new(Riffer::Agent) do
      identifier "test-agent"
      model "mock/riffer-1"
      instructions "You are a helpful assistant."
    end
  end

  describe ".identifier" do
    it "sets the identifier" do
      expect(agent_class.identifier).must_equal "test-agent"
    end

    it "defaults to snake_case class name when not set" do
      expect(Riffer::Agent.identifier).must_equal "riffer/agent"
    end

    it "derives the identifier once and reuses it" do
      klass = Class.new(Riffer::Agent)
      Object.const_set(:AgentTestMemoizedAgent, klass)

      expect(klass.identifier).must_equal "agent_test_memoized_agent"

      with_class_name_converter_returning("re-derived") do
        expect(klass.identifier).must_equal "agent_test_memoized_agent"
      end
    ensure
      Object.send(:remove_const, :AgentTestMemoizedAgent)
    end

    it "does not cache an identifier derived before the class is named" do
      klass = Class.new(Riffer::Agent)

      expect(klass.identifier).must_equal ""

      Object.const_set(:AgentTestLateNamedAgent, klass)

      expect(klass.identifier).must_equal "agent_test_late_named_agent"
    ensure
      Object.send(:remove_const, :AgentTestLateNamedAgent)
    end

    it "prefers an explicit identifier over a cached derived one" do
      klass = Class.new(Riffer::Agent)
      Object.const_set(:AgentTestExplicitAgent, klass)
      klass.identifier
      klass.identifier("explicit-agent")

      expect(klass.identifier).must_equal "explicit-agent"
    ensure
      Object.send(:remove_const, :AgentTestExplicitAgent)
    end
  end

  describe ".model" do
    it "sets the model" do
      expect(agent_class.model).must_equal "mock/riffer-1"
    end
  end

  describe ".instructions" do
    it "sets the instructions" do
      expect(agent_class.instructions).must_equal "You are a helpful assistant."
    end
  end

  describe ".model_options" do
    it "sets the model options" do
      agent_class.model_options(reasoning: "medium")

      expect(agent_class.model_options).must_equal({ reasoning: "medium" })
    end
  end

  describe ".max_steps" do
    it "sets the value" do
      agent_class.max_steps(5)

      expect(agent_class.max_steps).must_equal 5
    end
  end

  describe "#initialize" do
    it "seeds the session with the configured instruction system message" do
      agent = agent_class.new

      expect(agent.session.messages.map(&:role)).must_equal [:system]
      expect(agent.session.messages.first.content).must_equal "You are a helpful assistant."
    end

    it "leaves the session empty when no instructions or skills are configured" do
      bare = Class.new(Riffer::Agent) { model "mock/riffer-1" }.new

      expect(bare.session.messages).must_equal []
    end

    it "uses the provided session as-is when passed" do
      seeded = Riffer::Agent::Session.new(messages: [Riffer::Messages::User.new("Hi")])
      agent = agent_class.new(session: seeded)

      expect(agent.session).must_be_same_as seeded
      expect(agent.session.messages.map(&:role)).must_equal [:user]
    end

    it "initializes with nil token_usage" do
      agent = agent_class.new

      expect(agent.context.token_usage).must_be_nil
    end

    it "does not mutate a caller-supplied context Hash" do
      shared = { tenant: "alpha" }
      agent_class.new(context: shared).generate("hi")

      expect(shared).must_equal({ tenant: "alpha" })
    end

    it "isolates context between agents constructed with the same Hash" do
      shared = { tenant: "alpha" }
      first = agent_class.new(context: shared)
      second = agent_class.new(context: shared)
      first.generate("hi")

      expect(second.context[:token_usage]).must_be_nil
    end

    describe "with invalid model format" do
      let(:invalid_agent_class) do
        Class.new(Riffer::Agent) do
          model "invalid-format"
        end
      end

      it "raises error for missing provider or model name" do
        error = expect { invalid_agent_class.new }.must_raise(Riffer::ArgumentError)
        expect(error.message).must_match(/Invalid model string: invalid-format/)
      end
    end

    describe "with unregistered provider" do
      it "raises Riffer::ArgumentError at Agent.new" do
        klass = Class.new(Riffer::Agent) do
          model "nonexistent/gpt-4"
        end
        error = expect { klass.new }.must_raise(Riffer::ArgumentError)
        expect(error.message).must_match(/Provider not found: nonexistent/)
      end
    end

    describe "with dynamic instructions" do
      it "resolves the Proc at Agent.new and seeds the session" do
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          instructions -> { "Dynamic instructions" }
        end

        agent = klass.new
        system_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }

        expect(system_message.content).must_equal "Dynamic instructions"
      end

      it "passes context to the Proc" do
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          instructions ->(context) { "You are assisting #{context[:name]}" }
        end

        agent = klass.new(context: { name: "Jane" })
        system_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }

        expect(system_message.content).must_equal "You are assisting Jane"
      end

      it "passes an empty context Hash when not provided" do
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          instructions ->(context) { context[:name].nil? ? "No name" : "With name #{context[:name]}" }
        end

        agent = klass.new
        system_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }

        expect(system_message.content).must_equal "No name"
      end

      it "does not add a system message when the Proc returns nil" do
        returner = ->(_context) {}
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          instructions returner
        end

        agent = klass.new
        system_message = agent.session.messages.find { |msg| msg.is_a?(Riffer::Messages::System) }

        expect(system_message).must_be_nil
      end
    end
  end

  describe ".config" do
    it "returns a Riffer::Agent::Config" do
      klass = Class.new(Riffer::Agent) { model "mock/riffer-1" }

      expect(klass.config).must_be_instance_of Riffer::Agent::Config
    end

    it "returns the same instance across multiple reads on one class" do
      klass = Class.new(Riffer::Agent) { model "mock/riffer-1" }

      expect(klass.config).must_be_same_as klass.config
    end

    it "is independent between sibling subclasses" do
      sibling_a = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        max_steps 3
      end
      sibling_b = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        max_steps 7
      end

      expect(sibling_a.config).wont_be_same_as sibling_b.config
      expect(sibling_a.config.max_steps).must_equal 3
      expect(sibling_b.config.max_steps).must_equal 7
    end

    it "is independent between parent and child subclasses" do
      parent = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        max_steps 3
      end
      child = Class.new(parent)

      expect(child.config).wont_be_same_as parent.config
      # Each subclass starts fresh; only tool_runtime walks the chain.
      expect(child.config.max_steps).must_equal Riffer::Agent::Config::DEFAULT_MAX_STEPS
    end
  end

  describe "Agent.new(config:)" do
    let(:explicit_config) do
      Riffer::Agent::Config.new(
        model: "mock/riffer-1",
        instructions: "You are explicit.",
        max_steps: 4,
      )
    end

    it "uses the explicit config when provided" do
      agent = Riffer::Agent.new(config: explicit_config)

      expect(agent.session.messages.first.content).must_equal "You are explicit."
    end

    it "ignores the class config when config: is passed" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        instructions "Ignore me."
        max_steps 99
      end
      agent = klass.new(config: explicit_config)

      expect(agent.session.messages.first.content).must_equal "You are explicit."
      expect(agent.instance_variable_get(:@config).max_steps).must_equal 4
    end

    it "falls back to self.class.config when config: is omitted" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        instructions "From class."
      end
      agent = klass.new

      expect(agent.instance_variable_get(:@config)).must_be_same_as klass.config
    end

    it "threads context: through Procs in the explicit config" do
      cfg = Riffer::Agent::Config.new(
        model: "mock/riffer-1",
        instructions: ->(ctx) { "Hello #{ctx[:name]}" },
      )
      agent = Riffer::Agent.new(config: cfg, context: { name: "Jane" })

      expect(agent.session.messages.first.content).must_equal "Hello Jane"
    end

    it "uses an explicit config's model_options in the LLM call" do
      cfg = Riffer::Agent::Config.new(
        model: "mock/riffer-1",
        model_options: { temperature: 0.3 },
      )
      agent = Riffer::Agent.new(config: cfg)
      agent.generate("hi")

      expect(agent.provider.calls.last[:temperature]).must_equal 0.3
    end
  end

  describe ".structured_output" do
    it "stores Params instance" do
      params = Riffer::Params.new
      params.required(:sentiment, String)
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
      end
      klass.structured_output(params)

      expect(klass.structured_output).must_equal params
    end

    it "stores Params from block DSL" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        structured_output do
          required :sentiment, String, description: "The sentiment"
          optional :score, Float
        end
      end

      expect(klass.structured_output).must_be_instance_of Riffer::Params
      expect(klass.structured_output.parameters.size).must_equal 2
    end
  end

  describe ".generate with files" do
    it "passes files to the agent" do
      result = agent_class.generate("Describe this", files: [{ data: "aGVsbG8=", media_type: "image/png" }])

      expect(result).must_be_instance_of Riffer::Agent::Response
    end
  end

  describe ".stream with files" do
    it "passes files to the agent" do
      result = agent_class.stream("Describe this", files: [{ data: "aGVsbG8=", media_type: "image/png" }])

      expect(result).must_be_instance_of Enumerator
    end
  end

  describe ".find" do
    before do
      @test_agent_class = Class.new(Riffer::Agent) do
        identifier "findable-agent"
        model "mock/riffer-1"
      end
    end

    it "returns the agent class with matching identifier" do
      found_agent = Riffer::Agent.find("findable-agent")

      expect(found_agent).must_equal @test_agent_class
    end

    it "returns nil when identifier is not found" do
      found_agent = Riffer::Agent.find("nonexistent-agent")

      expect(found_agent).must_be_nil
    end
  end

  describe ".all" do
    before do
      @agent1 = Class.new(Riffer::Agent) do
        identifier "all-test-agent-1"
        model "mock/riffer-1"
      end

      @agent2 = Class.new(Riffer::Agent) do
        identifier "all-test-agent-2"
        model "mock/riffer-2"
      end
    end

    it "returns an array of agent classes" do
      result = Riffer::Agent.all

      expect(result).must_be_instance_of Array
    end

    it "includes agent 1" do
      all_agents = Riffer::Agent.all

      expect(all_agents).must_include @agent1
    end

    it "includes agent 2" do
      all_agents = Riffer::Agent.all

      expect(all_agents).must_include @agent2
    end
  end

  describe ".generate" do
    it "returns a Response object" do
      result = agent_class.generate("Hello")

      expect(result).must_be_instance_of Riffer::Agent::Response
    end

    it "passes context to tools" do
      context_tool = Class.new(Riffer::Tool) do
        description "Gets user info"
        params do
          required :field, String
        end
        def call(context:, field:)
          text(context[field.to_sym] || "unknown")
        end
      end
      context_tool.identifier("class_generate_context_tool")

      tool = context_tool
      received_context = nil
      custom_agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools lambda { |context|
          received_context = context
          [tool]
        }
      end

      custom_agent_class.generate("Hello", context: { user_name: "Bob" })

      expect(received_context[:user_name]).must_equal "Bob"
    end
  end

  describe ".stream" do
    it "returns an enumerator" do
      result = agent_class.stream("Hello")

      expect(result).must_be_instance_of Enumerator
    end

    it "yields stream events" do
      events = agent_class.stream("Hello").to_a

      expect(events).wont_be_empty
    end

    it "passes context to tools" do
      context_tool = Class.new(Riffer::Tool) do
        description "Gets user info"
        params do
          required :field, String
        end
        def call(context:, field:)
          text(context[field.to_sym] || "unknown")
        end
      end
      context_tool.identifier("class_stream_context_tool")

      tool = context_tool
      received_context = nil
      custom_agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools lambda { |context|
          received_context = context
          [tool]
        }
      end

      custom_agent_class.stream("Hello", context: { user_id: "42" }).each { |_| }

      expect(received_context[:user_id]).must_equal "42"
    end
  end

  describe ".uses_tools" do
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

    let(:agent_with_tools_class) do
      tool_class = weather_tool_class
      Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tool_class]
      end
    end

    it "returns nil when not set" do
      expect(agent_class.uses_tools).must_be_nil
    end

    it "sets the tools array" do
      expect(agent_with_tools_class.uses_tools).must_equal [weather_tool_class]
    end

    it "accepts a lambda" do
      tool_class = weather_tool_class
      agent = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools -> { [tool_class] }
      end

      expect(agent.uses_tools).must_be_instance_of Proc
    end
  end

  describe ".tool_runtime" do
    it "stores a tool_runtime class" do
      agent = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        tool_runtime Riffer::Tools::Runtime::Threaded
      end

      expect(agent.tool_runtime).must_equal Riffer::Tools::Runtime::Threaded
    end
  end

  describe "#tool_runtime" do
    def runtime_for(klass)
      agent = klass.new
      agent.tool_runtime
    end

    it "defaults to inline when no config" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
      end

      expect(runtime_for(klass)).must_be_instance_of Riffer::Tools::Runtime::Inline
    end

    it "resolves a ToolRuntime class to an instance" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        tool_runtime Riffer::Tools::Runtime::Threaded
      end

      expect(runtime_for(klass)).must_be_instance_of Riffer::Tools::Runtime::Threaded
    end

    it "uses global config as fallback" do
      original = Riffer.config.tool_runtime
      begin
        Riffer.config.tool_runtime = Riffer::Tools::Runtime::Threaded
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
        end

        expect(runtime_for(klass)).must_be_instance_of Riffer::Tools::Runtime::Threaded
      ensure
        Riffer.config.tool_runtime = original
      end
    end

    it "per-agent config overrides global config" do
      original = Riffer.config.tool_runtime
      begin
        Riffer.config.tool_runtime = Riffer::Tools::Runtime::Threaded
        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          tool_runtime Riffer::Tools::Runtime::Inline
        end

        expect(runtime_for(klass)).must_be_instance_of Riffer::Tools::Runtime::Inline
      ensure
        Riffer.config.tool_runtime = original
      end
    end

    it "resolves freshly per agent instance, threading context into the Proc" do
      received_contexts = []
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        tool_runtime lambda { |context|
          received_contexts << context
          Riffer::Tools::Runtime::Inline.new
        }
      end

      klass.new(context: { a: 1 }).tool_runtime
      klass.new(context: { b: 2 }).tool_runtime

      expect(received_contexts.map { |c| c[:a] || c[:b] }).must_equal [1, 2]
    end
  end

  describe ".guardrail" do
    let(:pass_guardrail_class) do
      Class.new(Riffer::Guardrail)
    end

    let(:block_guardrail_class) do
      Class.new(Riffer::Guardrail) do
        def process_input(_messages, context:)
          block("Input blocked")
        end

        def process_output(_response, messages:, context:)
          block("Output blocked")
        end
      end
    end

    it "registers before guardrails" do
      gr = pass_guardrail_class
      agent = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
      end
      agent.guardrail(:before, with: gr)
      configs = agent.guardrails_for(:before)

      expect(configs.any? { |c| c[:class] == gr }).must_equal true
    end

    it "stores options in config" do
      gr = pass_guardrail_class
      agent = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
      end
      agent.guardrail(:before, with: gr, foo: :bar)
      config = agent.guardrails_for(:before).first

      expect(config[:options]).must_equal({ foo: :bar })
    end
  end

  describe "#instruction_message" do
    it "returns a System message with instructions" do
      agent = agent_class.new

      expect(agent.instruction_message).must_be_instance_of Riffer::Messages::System
      expect(agent.instruction_message.content).must_equal "You are a helpful assistant."
    end

    it "returns nil when no instructions configured" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
      end

      expect(klass.new.instruction_message).must_be_nil
    end

    it "resolves dynamic instructions using the init context" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        instructions ->(context) { "Helping #{context[:name]}" }
      end
      agent = klass.new(context: { name: "Alice" })

      expect(agent.instruction_message.content).must_equal "Helping Alice"
    end

    it "returns nil when Proc returns nil" do
      returner = ->(_ctx) {}
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        instructions returner
      end

      expect(klass.new.instruction_message).must_be_nil
    end
  end

  describe "#skills_message" do
    it "returns nil when no skills configured" do
      agent = agent_class.new

      expect(agent.skills_message).must_be_nil
    end

    it "returns a System message when skills are configured" do
      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end
      agent = klass.new

      expect(agent.skills_message).must_be_instance_of Riffer::Messages::System
      expect(agent.skills_message.content).must_include "Available Skills"
    end
  end

  describe ".use_mcp / .mcp_configs" do
    after { clear_mcp_registry! }

    it "accumulates mcp_configs with progressive flag per call" do
      klass = Class.new(Riffer::Agent) do
        use_mcp :github
        use_mcp :jira, progressive: false
      end

      expect(klass.mcp_configs).must_equal [
        { tags: [:github], progressive: true },
        { tags: [:jira], progressive: false },
      ]
    end
  end

  describe "#tools" do
    after { clear_mcp_registry! }

    let(:fake_tool_class) do
      Class.new(Riffer::Mcp::Tool) do
        identifier "srv__mcp_tool"
        description "Fake MCP tool"
        @mcp_server_tool_name = "mcp_tool"
      end
    end

    def inject_ready_registration(name:, tags:, tools:)
      manifest = Riffer::Mcp::Manifest.new(name: name, tags: tags, endpoint: "https://x.com", discovery_headers: {})
      reg = Riffer::Mcp::Registration.allocate
      reg.instance_variable_set(:@manifest, manifest)
      reg.instance_variable_set(:@tools, tools)
      reg.instance_variable_set(:@mutex, Mutex.new)
      store = Riffer::Mcp::Registry.instance_variable_get(:@store)
      Riffer::Mcp::Registry.instance_variable_get(:@mutex).synchronize { store[name] = reg }
      reg
    end

    def resolved_tools_for(klass)
      klass.new.tools
    end

    def resolved_tools_and_context_for(klass)
      agent = klass.new
      [agent.tools, agent.context]
    end

    it "merges MCP tools with uses_tools tools" do
      static_tool = Class.new(Riffer::Tool) do
        identifier "static_tool"
        description "Static tool"
      end
      inject_ready_registration(name: "srv", tags: [:srv], tools: [fake_tool_class])

      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [static_tool]
        use_mcp :srv, progressive: false
      end

      tools = resolved_tools_for(klass)

      expect(tools).must_include static_tool
      expect(tools).must_include fake_tool_class
    end

    it "raises ArgumentError when tools share the same name" do
      static = Class.new(Riffer::Tool) do
        identifier "srv__mcp_tool"
        description "Static tool"
      end
      inject_ready_registration(name: "srv", tags: [:srv], tools: [fake_tool_class])

      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [static]
        use_mcp :srv, progressive: false
      end

      err = expect { resolved_tools_for(klass) }.must_raise Riffer::ArgumentError
      expect(err.message).must_match(/Duplicate tool names:.*srv__mcp_tool/)
    end

    it "returns MCP tools even when uses_tools is not set" do
      inject_ready_registration(name: "srv", tags: [:srv], tools: [fake_tool_class])

      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        use_mcp :srv, progressive: false
      end

      expect(resolved_tools_for(klass)).must_include fake_tool_class
    end

    it "omits MCP tools when credentials proc returns nil at resolve time" do
      inject_ready_registration(name: "srv", tags: [:srv], tools: [fake_tool_class])
      prev = Riffer.config.mcp.credentials
      Riffer.config.mcp.credentials = lambda do |manifest:, matched_tags:, context:|
      end

      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        use_mcp :srv, progressive: false
      end

      expect(resolved_tools_for(klass)).must_be_empty
    ensure
      Riffer.config.mcp.credentials = prev
    end

    it "uses AuthenticatedTool wrappers when credentials proc is set" do
      inject_ready_registration(name: "srv", tags: [:srv], tools: [fake_tool_class])
      prev = Riffer.config.mcp.credentials
      Riffer.config.mcp.credentials = ->(manifest:, matched_tags:, context:) { { "Authorization" => "Bearer x" } }

      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        use_mcp :srv, progressive: false
      end

      tools = resolved_tools_for(klass)

      expect(tools.size).must_equal 1
      expect(tools.first).wont_equal fake_tool_class
      expect(tools.first.name).must_equal fake_tool_class.name
    ensure
      Riffer.config.mcp.credentials = prev
    end

    describe "progressive mode" do
      let(:fake_tool_a) do
        Class.new(Riffer::Mcp::Tool) do
          identifier "srv__tool_a"
          description "Tool A"
          @mcp_server_tool_name = "tool_a"
        end
      end

      let(:fake_tool_b) do
        Class.new(Riffer::Mcp::Tool) do
          identifier "srv__tool_b"
          description "Tool B"
          @mcp_server_tool_name = "tool_b"
        end
      end

      it "returns mcp_search instead of individual tool classes" do
        inject_ready_registration(name: "srv", tags: [:srv], tools: [fake_tool_a, fake_tool_b])

        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          use_mcp :srv, progressive: true
        end

        tools = resolved_tools_for(klass)
        names = tools.map(&:name)

        expect(tools.size).must_equal 1
        expect(names).must_include "mcp_search"
      end

      it "search tool returns matching tools as inject_tools" do
        inject_ready_registration(name: "srv", tags: [:srv], tools: [fake_tool_a])

        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          use_mcp :srv, progressive: true
        end

        tools, ctx = resolved_tools_and_context_for(klass)
        st = tools.find { |t| t.name == "mcp_search" }
        resp = st.new.call(context: ctx, query: "tool_a")

        expect(resp.success?).must_equal true
        expect(resp.content).must_include "srv__tool_a"
        expect(resp.discovered_tools).wont_be_empty
        expect(resp.discovered_tools.map(&:name)).must_include "srv__tool_a"
      end

      it "mixes regular and progressive use_mcp in the same agent" do
        inject_ready_registration(name: "srv", tags: [:srv], tools: [fake_tool_a])
        inject_ready_registration(name: "other", tags: [:other], tools: [fake_tool_b])

        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          use_mcp :other, progressive: false
          use_mcp :srv, progressive: true
        end

        tools, ctx = resolved_tools_and_context_for(klass)
        names = tools.map(&:name)

        expect(names).must_include "srv__tool_b"
        expect(names).must_include "mcp_search"
        expect(names).wont_include "mcp_call"

        st = tools.find { |t| t.name == "mcp_search" }
        resp = st.new.call(context: ctx, query: "tool_a")

        expect(resp.content).must_include "srv__tool_a"
        expect(resp.content).wont_include "srv__tool_b"
      end

      it "accumulates tools from multiple progressive registrations into one mcp_search" do
        inject_ready_registration(name: "srv1", tags: [:g1], tools: [fake_tool_a])
        inject_ready_registration(name: "srv2", tags: [:g2], tools: [fake_tool_b])

        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          use_mcp :g1, progressive: true
          use_mcp :g2, progressive: true
        end

        tools, ctx = resolved_tools_and_context_for(klass)

        expect(tools.count { |t| t.name == "mcp_search" }).must_equal 1
        expect(tools.map(&:name)).wont_include "mcp_call"

        resp = tools.find { |t| t.name == "mcp_search" }.new.call(context: ctx, query: "tool")

        expect(resp.discovered_tools.map(&:name)).must_include "srv__tool_a"
        expect(resp.discovered_tools.map(&:name)).must_include "srv__tool_b"
      end

      it "omits progressive tools when credentials proc returns nil" do
        inject_ready_registration(name: "srv", tags: [:srv], tools: [fake_tool_a])
        prev = Riffer.config.mcp.credentials
        Riffer.config.mcp.credentials = ->(**) {}

        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          use_mcp :srv, progressive: true
        end

        expect(resolved_tools_for(klass)).must_be_empty
      ensure
        Riffer.config.mcp.credentials = prev
      end

      it "keeps regular tools but omits meta-tools when only progressive credentials return nil" do
        inject_ready_registration(name: "srv", tags: [:srv], tools: [fake_tool_a])
        inject_ready_registration(name: "other", tags: [:other], tools: [fake_tool_b])
        prev = Riffer.config.mcp.credentials
        Riffer.config.mcp.credentials = lambda { |matched_tags:, **|
          matched_tags.include?(:srv) ? nil : { token: "tok" }
        }

        klass = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          use_mcp :other, progressive: false
          use_mcp :srv, progressive: true
        end

        tools = resolved_tools_for(klass)
        names = tools.map(&:name)

        expect(names).wont_include "mcp_search"
        expect(tools).wont_be_empty
      ensure
        Riffer.config.mcp.credentials = prev
      end

      it "mcp_configs stores the progressive flag" do
        klass = Class.new(Riffer::Agent) do
          use_mcp :foo                       # default: true
          use_mcp :bar, progressive: false   # explicit opt-out
        end
        configs = klass.mcp_configs

        expect(configs.first[:progressive]).must_equal true
        expect(configs.last[:progressive]).must_equal false
      end

      it "defaults progressive to true when not specified" do
        klass = Class.new(Riffer::Agent) { use_mcp :foo }

        expect(klass.mcp_configs.first[:progressive]).must_equal true
      end
    end
  end

  describe "#tools validation" do
    it "raises when a tool is missing a description" do
      bad_tool = Class.new(Riffer::Tool) { identifier "bad_tool" }

      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [bad_tool]
      end

      err = expect { klass.new }.must_raise Riffer::ArgumentError
      expect(err.message).must_match(/must define a description/)
    end

    it "raises when an MCP tool is missing a description" do
      bad_mcp_tool = Class.new(Riffer::Tool) { identifier "bad_mcp_tool" }

      manifest = Riffer::Mcp::Manifest.new(name: "srv", tags: [:srv], endpoint: "https://x.com", discovery_headers: {})
      reg = Riffer::Mcp::Registration.allocate
      reg.instance_variable_set(:@manifest, manifest)
      reg.instance_variable_set(:@tools, [bad_mcp_tool])
      reg.instance_variable_set(:@mutex, Mutex.new)
      store = Riffer::Mcp::Registry.instance_variable_get(:@store)
      Riffer::Mcp::Registry.instance_variable_get(:@mutex).synchronize { store["srv"] = reg }

      klass = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        use_mcp :srv, progressive: false
      end

      err = expect { klass.new }.must_raise Riffer::ArgumentError
      expect(err.message).must_match(/must define a description/)
    ensure
      clear_mcp_registry!
    end
  end

  describe "interrupt! with experimental_history_healing" do
    let(:tool_class) do
      Class.new(Riffer::Tool) do
        identifier "interrupt_heal_tool"
        description "Slow tool"
        def call(context:)
          text("done")
        end
      end
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
      provider.stub_response(
        "",
        tool_calls: [
          { name: "interrupt_heal_tool", arguments: "{}" },
          { name: "interrupt_heal_tool", arguments: "{}" },
        ],
      )

      agent.session.on_message do |msg|
        agent.interrupt!(:user_interrupt) if msg.is_a?(Riffer::Messages::Assistant) && !msg.tool_calls.empty?
      end

      result = agent.generate("Call tools")

      expect(result.interrupted?).must_equal true
      expect(result.healed_tool_call_ids.length).must_equal 2
      expect(agent.session.orphaned_tool_call_ids).must_equal []
      tools = agent.session.messages.grep(Riffer::Messages::Tool)

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
      provider.stub_response("", tool_calls: [{ name: "interrupt_heal_tool", arguments: "{}" }])

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
      provider.stub_response("", tool_calls: [{ name: "interrupt_heal_tool", arguments: "{}" }])

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
        identifier "max_steps_heal_tool"
        description "Loop tool"
        def call(context:)
          text("ok")
        end
      end
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
      provider.stub_response("", tool_calls: [{ name: "max_steps_heal_tool", arguments: "{}" }])
      provider.stub_response("", tool_calls: [{ name: "max_steps_heal_tool", arguments: "{}" }])

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
      provider.stub_response("", tool_calls: [{ name: "max_steps_heal_tool", arguments: "{}" }])
      provider.stub_response("", tool_calls: [{ name: "max_steps_heal_tool", arguments: "{}" }])

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
      seeded = Riffer::Agent::Session.new(
        messages: [
          Riffer::Messages::User.new("hi"),
          Riffer::Messages::Tool.new(
            "ghost",
            tool_call_id: "c_missing",
            name: "t",
          ),
          Riffer::Messages::Assistant.new("", tool_calls: [tc]),
          Riffer::Messages::User.new("follow up"),
          Riffer::Messages::Assistant.new("ok"),
        ],
      )
      agent = custom_class.new(session: seeded)
      agent.provider.stub_response("Hello!")
      agent.generate

      assistant_with_orphan = agent.session.messages.find do |m|
        m.is_a?(Riffer::Messages::Assistant) && m.tool_calls.any? { |x| x.call_id == "c_orphan" }
      end

      refute_nil assistant_with_orphan
      parentless = agent.session.messages.find do |m|
        m.is_a?(Riffer::Messages::Tool) && m.tool_call_id == "c_missing"
      end

      refute_nil parentless
    end

    it "preserves a pending tool_use on the resume boundary even when healing is on" do
      Riffer.config.experimental_history_healing = true
      tc = Riffer::Messages::Assistant::ToolCall.new(call_id: "c_pending", name: "pending_seed_tool", arguments: "{}")
      seeded = Riffer::Agent::Session.new(
        messages: [
          Riffer::Messages::User.new("Call tool"),
          Riffer::Messages::Assistant.new("", tool_calls: [tc]),
        ],
      )
      tool = Class.new(Riffer::Tool) do
        identifier "pending_seed_tool"
        description "Pending tool"
        def call(context:)
          text("done")
        end
      end
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
end
