# frozen_string_literal: true

require "test_helper"

describe "Agent skills integration" do
  let(:backend) { Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH) }

  describe "generate with skills" do
    it "injects skills catalog into separate system message" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        instructions "You are helpful."
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      system_messages = agent.session.messages.grep(Riffer::Messages::System)

      assert_equal 2, system_messages.length
      assert_includes system_messages[0].content, "You are helpful."
      assert_includes system_messages[1].content, "Available Skills"
      assert_includes system_messages[1].content, "code-review"
      assert_includes system_messages[1].content, "data-analysis"
    end

    it "uses Markdown renderer for mock provider by default" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      system_messages = agent.session.messages.grep(Riffer::Messages::System)
      skills_message = system_messages.find { |m| m.content.include?("Available Skills") }

      assert_includes skills_message.content, "## Available Skills"
      assert_includes skills_message.content, "- **code-review**"
    end

    it "allows custom adapter override" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
          adapter Riffer::Skills::XmlAdapter
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      system_messages = agent.session.messages.grep(Riffer::Messages::System)
      skills_message = system_messages.find { |m| m.content.include?("available_skills") }

      assert_includes skills_message.content, "<available_skills>"
    end

    it "uses XML renderer for mock provider when the model name contains claude" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/claude-sonnet-4-6"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      system_messages = agent.session.messages.grep(Riffer::Messages::System)
      skills_message = system_messages.find { |m| m.content.include?("<available_skills>") }

      refute_nil skills_message
      assert_includes skills_message.content, "<available_skills>"
    end

    it "explicit adapter wins over model-aware default" do
      # Mock with a "claude" model name would default to XML; explicit
      # MarkdownAdapter must still take precedence.
      agent_class = Class.new(Riffer::Agent) do
        model "mock/claude-sonnet-4-6"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
          adapter Riffer::Skills::MarkdownAdapter
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      system_messages = agent.session.messages.grep(Riffer::Messages::System)
      skills_message = system_messages.find { |m| m.content.include?("Available Skills") }

      refute_nil skills_message
      assert_includes skills_message.content, "## Available Skills"
    end

    it "selects XmlAdapter for amazon_bedrock with an Anthropic model id" do
      agent_class = Class.new(Riffer::Agent) do
        model "amazon_bedrock/us.anthropic.claude-sonnet-4-6"
        provider_options region: "us-west-2"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new

      skills_state = agent.context.skills

      refute_nil skills_state
      assert_kind_of Riffer::Skills::XmlAdapter, skills_state.adapter
    end

    it "selects MarkdownAdapter for amazon_bedrock with a non-Anthropic model id" do
      agent_class = Class.new(Riffer::Agent) do
        model "amazon_bedrock/us.amazon.nova-lite-v1:0"
        provider_options region: "us-west-2"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new

      skills_state = agent.context.skills

      refute_nil skills_state
      assert_kind_of Riffer::Skills::MarkdownAdapter, skills_state.adapter
    end

    it "includes skill_activate tool in resolved tools" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      tool_names = agent.tools.map(&:name)

      assert_includes tool_names, "skill_activate"
    end

    it "merges skill tools with existing tools" do
      tool_class = Class.new(Riffer::Tool) do
        identifier "my_tool"
        description "A custom tool"
        def call(context:)
          text("ok")
        end
      end

      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tool_class]
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      tool_names = agent.tools.map(&:name)

      assert_includes tool_names, "my_tool"
      assert_includes tool_names, "skill_activate"
    end

    it "raises on tool name conflict" do
      conflict_tool = Class.new(Riffer::Tool) do
        identifier "skill_activate"
        description "Conflicts with skill_activate"
        def call(context:)
          text("ok")
        end
      end

      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [conflict_tool]
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      error = assert_raises(Riffer::ArgumentError) { agent_class.new }
      assert_match(/Tool name conflict/, error.message)
    end

    it "passes skills context in context" do
      tool_class = Class.new(Riffer::Tool) do
        identifier "spy_tool"
        description "Captures context"
        def call(context:)
          text(context[:skills].skills.keys.sort.join(","))
        end
      end

      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tool_class]
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.provider.stub_response("", tool_calls: [{ name: "spy_tool", arguments: "{}" }])
      agent.provider.stub_response("Done")
      agent.generate("Hello")

      tool_msg = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::Tool) && m.name == "spy_tool" }

      refute_nil tool_msg
      assert_includes tool_msg.content, "code-review"
      assert_includes tool_msg.content, "data-analysis"
    end

    it "handles Proc backend" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend lambda { |_ctx|
            Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
          }
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      system_messages = agent.session.messages.grep(Riffer::Messages::System)
      skills_msg = system_messages.find { |m| m.content.include?("code-review") }

      refute_nil skills_msg
    end

    it "generates no system message when skills backend returns empty" do
      Dir.mktmpdir do |dir|
        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          skills do
            backend Riffer::Skills::FilesystemBackend.new(dir)
          end
        end

        agent = agent_class.new
        agent.generate("Hello")

        system_message = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::System) }

        assert_nil system_message
      end
    end

    it "falls back to Riffer.config.skills.default_backend when agent has no per-agent backend" do
      original_default = Riffer.config.skills.default_backend
      Riffer.config.skills.default_backend = Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)

      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          # no per-agent backend; should pick up the global default
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      skills_message = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::System) && m.content.include?("Available Skills") }

      refute_nil skills_message
      assert_includes skills_message.content, "code-review"
    ensure
      Riffer.config.skills.default_backend = original_default
    end

    it "per-agent backend takes precedence over default_backend" do
      original_default = Riffer.config.skills.default_backend
      decoy_backend = Class.new(Riffer::Skills::Backend) do
        def list_skills
          raise "default_backend should not be consulted when agent has its own"
        end

        def read_skill(name); end
      end.new
      Riffer.config.skills.default_backend = decoy_backend

      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      skills_message = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::System) && m.content.include?("Available Skills") }

      refute_nil skills_message
    ensure
      Riffer.config.skills.default_backend = original_default
    end
  end

  describe "#tools" do
    it "returns uses_tools when no skills configured" do
      tool_class = Class.new(Riffer::Tool) do
        identifier "my_tool"
        description "A tool"
        def call(context:)
          text("ok")
        end
      end

      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        uses_tools [tool_class]
      end

      assert_equal ["my_tool"], agent_class.new.tools.map(&:name)
    end

    it "appends skill_activate when skills block is configured" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      tool_names = agent_class.new.tools.map(&:name)

      assert_includes tool_names, "skill_activate"
    end

    it "uses the per-agent activate_tool override" do
      custom = Class.new(Riffer::Tool) do
        identifier "my_activate"
        description "Custom"
        def call(context:)
          text("ok")
        end
      end

      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
          activate_tool custom
        end
      end

      tool_names = agent_class.new.tools.map(&:name)

      assert_includes tool_names, "my_activate"
      refute_includes tool_names, "skill_activate"
    end
  end

  describe "activated skills" do
    it "appends activated skill bodies to skills system message" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        instructions "Base instructions."
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
          activate ["code-review"]
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      system_messages = agent.session.messages.grep(Riffer::Messages::System)

      assert_equal 2, system_messages.length
      assert_includes system_messages[0].content, "Base instructions."
      skills_msg = system_messages[1]

      assert_includes skills_msg.content, "code review assistant"
      # Pre-activated skill should not appear in the catalog
      refute_includes skills_msg.content, "- **code-review**"
      # Non-activated skill should still be in the catalog
      assert_includes skills_msg.content, "- **data-analysis**"
    end

    it "omits catalog entirely when all skills are pre-activated" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
          activate %w[code-review data-analysis]
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      system_messages = agent.session.messages.grep(Riffer::Messages::System)
      skills_msg = system_messages.find { |m| m.content.include?("code review assistant") }

      refute_nil skills_msg
      refute_includes skills_msg.content, "Available Skills"
      assert_includes skills_msg.content, "code review assistant"
      assert_includes skills_msg.content, "data analysis assistant"
    end

    it "raises on unknown activated skill" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
          activate ["nonexistent"]
        end
      end

      error = assert_raises(Riffer::ArgumentError) { agent_class.new }
      assert_match(/Unknown skill/, error.message)
    end

    it "supports Proc for activate" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
          activate ->(ctx) { ctx&.dig(:activate_skills) || [] }
        end
      end

      agent = agent_class.new(context: { activate_skills: ["data-analysis"] })
      agent.generate("Hello")

      system_messages = agent.session.messages.grep(Riffer::Messages::System)
      skills_msg = system_messages.find { |m| m.content.include?("data analysis assistant") }

      refute_nil skills_msg
    end
  end

  describe "stream with skills" do
    it "injects skills catalog into separate system message" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        instructions "You are helpful."
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.stream("Hello").each { |_| }

      system_messages = agent.session.messages.grep(Riffer::Messages::System)

      assert_equal 2, system_messages.length
      skills_msg = system_messages.find { |m| m.content.include?("Available Skills") }

      refute_nil skills_msg
      assert_includes skills_msg.content, "code-review"
    end
  end

  describe "stream emits SkillActivation events" do
    it "emits SkillActivation event when skill is activated via tool call" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.provider.stub_response("", tool_calls: [{ name: "skill_activate", arguments: '{"name":"code-review"}' }])
      agent.provider.stub_response("Here is my review.")

      events = agent.stream("Review this code").grep(Riffer::StreamEvents::SkillActivation)

      assert_equal 1, events.size
      assert_equal "code-review", events.first.name
      assert_equal :system, events.first.role
    end

    it "does not emit duplicate events for re-activation of the same skill" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.provider.stub_response("", tool_calls: [{ name: "skill_activate", arguments: '{"name":"code-review"}' }])
      agent.provider.stub_response("", tool_calls: [{ name: "skill_activate", arguments: '{"name":"code-review"}' }])
      agent.provider.stub_response("Done.")

      events = agent.stream("Review").grep(Riffer::StreamEvents::SkillActivation)

      assert_equal 1, events.size
    end

    it "composes with and restores the consumer's on_activate across a stream" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      fired = []
      agent.context.skills.on_activate = ->(name) { fired << name }
      agent.provider.stub_response("", tool_calls: [{ name: "skill_activate", arguments: '{"name":"code-review"}' }])
      agent.provider.stub_response("Done.")

      agent.stream("Review").each { |_| }
      agent.context.skills.activate("data-analysis")

      assert_equal %w[code-review data-analysis], fired
    end
  end

  describe "skill activation end-to-end" do
    it "activates a skill via tool call and returns body" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.provider.stub_response("", tool_calls: [{ name: "skill_activate", arguments: '{"name":"code-review"}' }])
      agent.provider.stub_response("Here is my review.")
      response = agent.generate("Review this code")

      assert_equal "Here is my review.", response.content

      tool_msg = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::Tool) && m.name == "skill_activate" }

      refute_nil tool_msg
      assert_includes tool_msg.content, "code review assistant"
      refute tool_msg.error
    end

    it "returns error for unknown skill activation" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.provider.stub_response("", tool_calls: [{ name: "skill_activate", arguments: '{"name":"nonexistent"}' }])
      agent.provider.stub_response("Sorry, skill not found.")
      agent.generate("Use nonexistent skill")

      tool_msg = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::Tool) && m.name == "skill_activate" }

      refute_nil tool_msg
      assert_includes tool_msg.content, "Unknown skill"
    end

    it "answers a re-activation with a pointer instead of the body" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.provider.stub_response("", tool_calls: [{ name: "skill_activate", arguments: '{"name":"code-review"}' }])
      agent.provider.stub_response("", tool_calls: [{ name: "skill_activate", arguments: '{"name":"code-review"}' }])
      agent.provider.stub_response("Done.")
      agent.generate("Review this code")

      tool_msgs = agent.session.messages.select { |m| m.is_a?(Riffer::Messages::Tool) && m.name == "skill_activate" }

      assert_includes tool_msgs.last.content, "already active"
      refute_includes tool_msgs.last.content, "code review assistant"
    end
  end

  describe "user-explicit activation" do
    it "injects the wrapped body as a user message and pointers later model activations" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      skills = agent.context.skills
      agent.session.add(
        Riffer::Messages::User.new("#{skills.activation_prompt('code-review')}\n\nfocus on security"),
        silent: true,
      )

      agent.provider.stub_response("", tool_calls: [{ name: "skill_activate", arguments: '{"name":"code-review"}' }])
      agent.provider.stub_response("Done.")
      agent.generate

      tool_msg = agent.session.messages.find { |m| m.is_a?(Riffer::Messages::Tool) && m.name == "skill_activate" }

      assert_includes tool_msg.content, "already active"
    end
  end

  describe "disable-model-invocation" do
    def write_skill(dir, name, description, disable_model_invocation: false)
      Dir.mkdir(File.join(dir, name))
      lines = ["---", "name: #{name}", "description: #{description}"]
      lines << "disable-model-invocation: true" if disable_model_invocation
      lines << "---"
      File.write(File.join(dir, name, "SKILL.md"), "#{lines.join("\n")}\n\nBody for #{name}.")
    end

    it "hides a disabled skill from the catalog" do
      Dir.mktmpdir do |dir|
        write_skill(dir, "code-review", "Reviews code.")
        write_skill(dir, "deploy-prod", "Deploys to production.", disable_model_invocation: true)

        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          skills do
            backend Riffer::Skills::FilesystemBackend.new(dir)
          end
        end

        refute_includes agent_class.new.context.skills.system_prompt, "deploy-prod"
      end
    end

    it "registers skill_activate when an enabled skill exists alongside a disabled one" do
      Dir.mktmpdir do |dir|
        write_skill(dir, "code-review", "Reviews code.")
        write_skill(dir, "deploy-prod", "Deploys to production.", disable_model_invocation: true)

        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          skills do
            backend Riffer::Skills::FilesystemBackend.new(dir)
          end
        end

        assert_includes agent_class.new.tools.map(&:name), "skill_activate"
      end
    end

    it "omits skill_activate when every skill disables model invocation" do
      Dir.mktmpdir do |dir|
        write_skill(dir, "deploy-prod", "Deploys to production.", disable_model_invocation: true)

        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          skills do
            backend Riffer::Skills::FilesystemBackend.new(dir)
          end
        end

        refute_includes agent_class.new.tools.map(&:name), "skill_activate"
      end
    end

    it "activates a disabled skill through the programmatic activate config" do
      Dir.mktmpdir do |dir|
        write_skill(dir, "deploy-prod", "Deploys to production.", disable_model_invocation: true)

        agent_class = Class.new(Riffer::Agent) do
          model "mock/riffer-1"
          skills do
            backend Riffer::Skills::FilesystemBackend.new(dir)
            activate ["deploy-prod"]
          end
        end

        skills_message = agent_class.new.session.messages.find { |m| m.is_a?(Riffer::Messages::System) && m.content.include?("Body for deploy-prod.") }

        refute_nil skills_message
      end
    end
  end
end
