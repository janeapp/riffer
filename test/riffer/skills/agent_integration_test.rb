# frozen_string_literal: true

require "test_helper"

SKILLS_FIXTURES_PATH = File.expand_path("../../fixtures/skills", __dir__)

describe "Agent skills integration" do
  let(:backend) { Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH) }

  describe "generate with skills" do
    it "injects skills catalog into system prompt" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        instructions "You are helpful."
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      system_message = agent.messages.find { |m| m.is_a?(Riffer::Messages::System) }
      refute_nil system_message
      assert_includes system_message.content, "You are helpful."
      assert_includes system_message.content, "Available Skills"
      assert_includes system_message.content, "code-review"
      assert_includes system_message.content, "data-analysis"
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

      system_message = agent.messages.find { |m| m.is_a?(Riffer::Messages::System) }
      assert_includes system_message.content, "## Available Skills"
      assert_includes system_message.content, "- **code-review**"
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

      system_message = agent.messages.find { |m| m.is_a?(Riffer::Messages::System) }
      assert_includes system_message.content, "<available_skills>"
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

      tool_names = agent.send(:resolved_tools).map(&:name)
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

      tool_names = agent.send(:resolved_tools).map(&:name)
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

      agent = agent_class.new
      error = assert_raises(Riffer::ArgumentError) { agent.generate("Hello") }
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

      provider = Riffer::Providers::Mock.new
      provider.stub_response("", tool_calls: [{name: "spy_tool", arguments: "{}"}])
      provider.stub_response("Done")

      agent = agent_class.new
      agent.instance_variable_set(:@provider_instance, provider)
      agent.generate("Hello")

      tool_msg = agent.messages.find { |m| m.is_a?(Riffer::Messages::Tool) && m.name == "spy_tool" }
      refute_nil tool_msg
      assert_includes tool_msg.content, "code-review"
      assert_includes tool_msg.content, "data-analysis"
    end

    it "handles Proc backend" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend ->(ctx) {
            Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
          }
        end
      end

      agent = agent_class.new
      agent.generate("Hello")

      system_message = agent.messages.find { |m| m.is_a?(Riffer::Messages::System) }
      assert_includes system_message.content, "code-review"
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

        system_message = agent.messages.find { |m| m.is_a?(Riffer::Messages::System) }
        assert_nil system_message
      end
    end
  end

  describe "activated skills" do
    it "appends activated skill bodies to system prompt" do
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

      system_message = agent.messages.find { |m| m.is_a?(Riffer::Messages::System) }
      assert_includes system_message.content, "Base instructions."
      assert_includes system_message.content, "Available Skills"
      assert_includes system_message.content, "code review assistant"
    end

    it "raises on unknown activated skill" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
          activate ["nonexistent"]
        end
      end

      agent = agent_class.new
      error = assert_raises(Riffer::ArgumentError) { agent.generate("Hello") }
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

      agent = agent_class.new
      agent.generate("Hello", context: {activate_skills: ["data-analysis"]})

      system_message = agent.messages.find { |m| m.is_a?(Riffer::Messages::System) }
      assert_includes system_message.content, "data analysis assistant"
    end
  end

  describe "stream with skills" do
    it "injects skills catalog into system prompt" do
      agent_class = Class.new(Riffer::Agent) do
        model "mock/riffer-1"
        instructions "You are helpful."
        skills do
          backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH)
        end
      end

      agent = agent_class.new
      agent.stream("Hello").each { |_| }

      system_message = agent.messages.find { |m| m.is_a?(Riffer::Messages::System) }
      refute_nil system_message
      assert_includes system_message.content, "Available Skills"
      assert_includes system_message.content, "code-review"
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

      provider = Riffer::Providers::Mock.new
      provider.stub_response("", tool_calls: [{name: "skill_activate", arguments: '{"name":"code-review"}'}])
      provider.stub_response("Here is my review.")

      agent = agent_class.new
      agent.instance_variable_set(:@provider_instance, provider)

      events = agent.stream("Review this code").select { |e| e.is_a?(Riffer::StreamEvents::SkillActivation) }

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

      provider = Riffer::Providers::Mock.new
      provider.stub_response("", tool_calls: [{name: "skill_activate", arguments: '{"name":"code-review"}'}])
      provider.stub_response("", tool_calls: [{name: "skill_activate", arguments: '{"name":"code-review"}'}])
      provider.stub_response("Done.")

      agent = agent_class.new
      agent.instance_variable_set(:@provider_instance, provider)

      events = agent.stream("Review").select { |e| e.is_a?(Riffer::StreamEvents::SkillActivation) }

      assert_equal 1, events.size
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

      provider = Riffer::Providers::Mock.new
      provider.stub_response("", tool_calls: [{name: "skill_activate", arguments: '{"name":"code-review"}'}])
      provider.stub_response("Here is my review.")

      agent = agent_class.new
      agent.instance_variable_set(:@provider_instance, provider)
      response = agent.generate("Review this code")

      assert_equal "Here is my review.", response.content

      tool_msg = agent.messages.find { |m| m.is_a?(Riffer::Messages::Tool) && m.name == "skill_activate" }
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

      provider = Riffer::Providers::Mock.new
      provider.stub_response("", tool_calls: [{name: "skill_activate", arguments: '{"name":"nonexistent"}'}])
      provider.stub_response("Sorry, skill not found.")

      agent = agent_class.new
      agent.instance_variable_set(:@provider_instance, provider)
      agent.generate("Use nonexistent skill")

      tool_msg = agent.messages.find { |m| m.is_a?(Riffer::Messages::Tool) && m.name == "skill_activate" }
      refute_nil tool_msg
      assert_includes tool_msg.content, "Unknown skill"
    end
  end
end
