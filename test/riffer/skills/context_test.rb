# frozen_string_literal: true

require "test_helper"

describe Riffer::Skills::Context do
  let(:fake_backend) do
    Class.new(Riffer::Skills::Backend) do
      attr_reader :reads

      def initialize
        super
        @reads = []
      end

      def list_skills
        []
      end

      def read_skill(name)
        @reads << name
        "BODY:#{name}"
      end
    end.new
  end

  let(:adapter) { Riffer::Skills::MarkdownAdapter.new(skill_activate_tool: Riffer::Skills::ActivateTool) }
  let(:enabled) { Riffer::Skills::Frontmatter.new(name: "code-review", description: "Reviews code.") }
  let(:other) { Riffer::Skills::Frontmatter.new(name: "data-analysis", description: "Analyzes data.") }
  let(:disabled) { Riffer::Skills::Frontmatter.new(name: "deploy-prod", description: "Deploys to production.", disable_model_invocation: true) }

  def build_context(skills)
    Riffer::Skills::Context.new(backend: fake_backend, skills: skills, adapter: adapter)
  end

  describe "#model_invocable?" do
    it "returns true for an enabled skill" do
      assert build_context({ "code-review" => enabled }).model_invocable?("code-review")
    end

    it "returns false for a disabled skill" do
      refute build_context({ "deploy-prod" => disabled }).model_invocable?("deploy-prod")
    end

    it "returns false for an unknown skill" do
      refute build_context({ "code-review" => enabled }).model_invocable?("nope")
    end
  end

  describe "#activatable?" do
    it "returns true when an enabled skill is available" do
      assert_predicate build_context({ "code-review" => enabled, "deploy-prod" => disabled }), :activatable?
    end

    it "returns false when every skill is disabled" do
      refute_predicate build_context({ "deploy-prod" => disabled }), :activatable?
    end
  end

  describe "#read" do
    it "returns the skill body" do
      assert_equal "BODY:code-review", build_context({ "code-review" => enabled }).read("code-review")
    end

    it "does not record an activation" do
      context = build_context({ "code-review" => enabled })
      context.read("code-review")

      refute context.activated?("code-review")
    end

    it "does not fire on_activate" do
      context = build_context({ "code-review" => enabled })
      fired = []
      context.on_activate = ->(name) { fired << name }
      context.read("code-review")

      assert_empty fired
    end

    it "caches the body across reads" do
      context = build_context({ "code-review" => enabled })
      context.read("code-review")
      context.read("code-review")

      assert_equal ["code-review"], fake_backend.reads
    end

    it "raises for an unknown skill" do
      error = assert_raises(Riffer::ArgumentError) { build_context({}).read("nope") }
      assert_match(/Unknown skill/, error.message)
    end

    it "reads a disabled skill" do
      assert_equal "BODY:deploy-prod", build_context({ "deploy-prod" => disabled }).read("deploy-prod")
    end
  end

  describe "#activate" do
    it "returns the skill body" do
      assert_equal "BODY:code-review", build_context({ "code-review" => enabled }).activate("code-review")
    end

    it "records the activation" do
      context = build_context({ "code-review" => enabled })
      context.activate("code-review")

      assert context.activated?("code-review")
    end

    it "returns the body again on re-activation" do
      context = build_context({ "code-review" => enabled })
      context.activate("code-review")

      assert_equal "BODY:code-review", context.activate("code-review")
    end

    it "fires on_activate only on the first activation" do
      context = build_context({ "code-review" => enabled })
      fired = []
      context.on_activate = ->(name) { fired << name }
      context.activate("code-review")
      context.activate("code-review")

      assert_equal ["code-review"], fired
    end

    it "reads the backend once across activations" do
      context = build_context({ "code-review" => enabled })
      context.activate("code-review")
      context.activate("code-review")

      assert_equal ["code-review"], fake_backend.reads
    end

    it "activates a disabled skill through the programmatic path" do
      assert_equal "BODY:deploy-prod", build_context({ "deploy-prod" => disabled }).activate("deploy-prod")
    end

    it "raises for an unknown skill" do
      error = assert_raises(Riffer::ArgumentError) { build_context({}).activate("nope") }
      assert_match(/Unknown skill/, error.message)
    end
  end

  describe "#activated?" do
    it "returns false before activation" do
      refute build_context({ "code-review" => enabled }).activated?("code-review")
    end
  end

  describe "#deactivate" do
    it "clears the activation" do
      context = build_context({ "code-review" => enabled })
      context.activate("code-review")
      context.deactivate("code-review")

      refute context.activated?("code-review")
    end

    it "fires on_activate again on the next activation" do
      context = build_context({ "code-review" => enabled })
      fired = []
      context.on_activate = ->(name) { fired << name }
      context.activate("code-review")
      context.deactivate("code-review")
      context.activate("code-review")

      assert_equal %w[code-review code-review], fired
    end

    it "raises for an unknown skill" do
      error = assert_raises(Riffer::ArgumentError) { build_context({}).deactivate("nope") }
      assert_match(/Unknown skill/, error.message)
    end
  end

  describe "#activation_prompt" do
    it "returns the body wrapped in skill_content tags" do
      prompt = build_context({ "code-review" => enabled }).activation_prompt("code-review")

      assert_equal %(<skill_content name="code-review">\nBODY:code-review\n</skill_content>), prompt
    end

    it "records the activation" do
      context = build_context({ "code-review" => enabled })
      context.activation_prompt("code-review")

      assert context.activated?("code-review")
    end

    it "wraps a disabled skill for user-channel injection" do
      prompt = build_context({ "deploy-prod" => disabled }).activation_prompt("deploy-prod")

      assert_includes prompt, %(<skill_content name="deploy-prod">)
    end

    it "raises for an unknown skill" do
      error = assert_raises(Riffer::ArgumentError) { build_context({}).activation_prompt("nope") }
      assert_match(/Unknown skill/, error.message)
    end
  end

  describe "#preactivate" do
    it "records the activation" do
      context = build_context({ "code-review" => enabled })
      context.preactivate("code-review")

      assert context.activated?("code-review")
    end

    it "renders the wrapped body in the system prompt" do
      context = build_context({ "code-review" => enabled })
      context.preactivate("code-review")

      assert_includes context.system_prompt, %(<skill_content name="code-review">\nBODY:code-review\n</skill_content>)
    end

    it "removes the skill from the catalog" do
      context = build_context({ "code-review" => enabled, "data-analysis" => other })
      context.preactivate("code-review")

      refute_includes context.system_prompt, "- **code-review**"
    end

    it "raises for an unknown skill" do
      error = assert_raises(Riffer::ArgumentError) { build_context({}).preactivate("nope") }
      assert_match(/Unknown skill/, error.message)
    end
  end

  describe "#system_prompt" do
    it "excludes disabled skills from the catalog" do
      refute_includes build_context({ "code-review" => enabled, "deploy-prod" => disabled }).system_prompt,
                      "deploy-prod"
    end

    it "keeps enabled skills in the catalog" do
      assert_includes build_context({ "code-review" => enabled, "deploy-prod" => disabled }).system_prompt,
                      "code-review"
    end

    it "excludes runtime-activated skill bodies" do
      context = build_context({ "code-review" => enabled, "data-analysis" => other })
      context.activate("code-review")

      refute_includes context.system_prompt, "BODY:code-review"
    end

    it "keeps runtime-activated skills in the catalog" do
      context = build_context({ "code-review" => enabled, "data-analysis" => other })
      context.activate("code-review")

      assert_includes context.system_prompt, "- **code-review**"
    end
  end
end
