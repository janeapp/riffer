# frozen_string_literal: true

require "test_helper"

describe Riffer::Skills::Context do
  let(:fake_backend) do
    Class.new(Riffer::Skills::Backend) do
      def list_skills
        []
      end

      def read_skill(name)
        "BODY:#{name}"
      end
    end.new
  end

  let(:adapter) { Riffer::Skills::MarkdownAdapter.new(skill_activate_tool: Riffer::Skills::ActivateTool) }
  let(:enabled) { Riffer::Skills::Frontmatter.new(name: "code-review", description: "Reviews code.") }
  let(:disabled) { Riffer::Skills::Frontmatter.new(name: "deploy-prod", description: "Deploys to production.", disable_model_invocation: true) }

  def build_context(skills)
    Riffer::Skills::Context.new(backend: fake_backend, skills: skills, adapter: adapter)
  end

  describe "#model_invocable?" do
    it "returns true for an enabled skill" do
      assert build_context({"code-review" => enabled}).model_invocable?("code-review")
    end

    it "returns false for a disabled skill" do
      refute build_context({"deploy-prod" => disabled}).model_invocable?("deploy-prod")
    end

    it "returns false for an unknown skill" do
      refute build_context({"code-review" => enabled}).model_invocable?("nope")
    end
  end

  describe "#activatable?" do
    it "returns true when an enabled skill is available" do
      assert build_context({"code-review" => enabled, "deploy-prod" => disabled}).activatable?
    end

    it "returns false when every skill is disabled" do
      refute build_context({"deploy-prod" => disabled}).activatable?
    end
  end

  describe "#system_prompt" do
    it "excludes disabled skills from the catalog" do
      refute_includes build_context({"code-review" => enabled, "deploy-prod" => disabled}).system_prompt, "deploy-prod"
    end

    it "keeps enabled skills in the catalog" do
      assert_includes build_context({"code-review" => enabled, "deploy-prod" => disabled}).system_prompt, "code-review"
    end
  end

  describe "#activate" do
    it "activates a disabled skill through the programmatic path" do
      assert_equal "BODY:deploy-prod", build_context({"deploy-prod" => disabled}).activate("deploy-prod")
    end
  end
end
