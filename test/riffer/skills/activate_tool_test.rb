# frozen_string_literal: true

require "test_helper"

describe Riffer::Skills::ActivateTool do
  let(:fixtures_path) { File.expand_path("../../../fixtures/skills", __FILE__) }
  let(:backend) { Riffer::Skills::FilesystemBackend.new(fixtures_path) }
  let(:skills) { backend.list_skills.to_h { |s| [s.name, s] } }
  let(:skills_context) { Riffer::Skills::Context.new(backend: backend, skills: skills, adapter: Riffer::Skills::MarkdownAdapter.new(skill_activate_tool: Riffer::Skills::ActivateTool)) }
  let(:context) do
    ctx = Riffer::Agent::Context.new
    ctx.skills = skills_context
    ctx
  end

  describe "#call" do
    it "returns skill body for a valid skill" do
      tool = Riffer::Skills::ActivateTool.new
      result = tool.call(context: context, name: "code-review")
      assert result.success?
      assert_includes result.content, "code review assistant"
    end

    it "wraps the body in skill_content tags" do
      tool = Riffer::Skills::ActivateTool.new
      result = tool.call(context: context, name: "code-review")
      assert_includes result.content, %(<skill_content name="code-review">)
    end

    it "returns a pointer instead of the body on re-activation" do
      tool = Riffer::Skills::ActivateTool.new
      tool.call(context: context, name: "code-review")
      result = tool.call(context: context, name: "code-review")
      assert result.success?
      assert_includes result.content, "already active"
      refute_includes result.content, "code review assistant"
    end

    it "returns the full body again after deactivation" do
      tool = Riffer::Skills::ActivateTool.new
      tool.call(context: context, name: "code-review")
      skills_context.deactivate("code-review")
      result = tool.call(context: context, name: "code-review")
      assert_includes result.content, "code review assistant"
    end

    it "returns a pointer when the skill was activated through the user channel" do
      tool = Riffer::Skills::ActivateTool.new
      skills_context.activation_prompt("code-review")
      result = tool.call(context: context, name: "code-review")
      assert_includes result.content, "already active"
    end

    it "returns error for unknown skill" do
      tool = Riffer::Skills::ActivateTool.new
      result = tool.call(context: context, name: "nonexistent")
      assert result.error?
      assert_includes result.content, "Unknown skill"
    end

    it "returns error for a skill that disables model invocation" do
      disabled = Riffer::Skills::Frontmatter.new(name: "deploy-prod", description: "Deploys.", disable_model_invocation: true)
      disabled_context = Riffer::Skills::Context.new(backend: backend, skills: {"deploy-prod" => disabled}, adapter: Riffer::Skills::MarkdownAdapter.new(skill_activate_tool: Riffer::Skills::ActivateTool))
      ctx = Riffer::Agent::Context.new
      ctx.skills = disabled_context

      tool = Riffer::Skills::ActivateTool.new
      result = tool.call(context: ctx, name: "deploy-prod")
      assert result.error?
      assert_includes result.content, "Unknown skill"
    end

    it "returns error when skills not configured" do
      tool = Riffer::Skills::ActivateTool.new
      result = tool.call(context: Riffer::Agent::Context.new, name: "code-review")
      assert result.error?
      assert_includes result.content, "Skills not configured"
    end

    it "returns error when context is nil" do
      tool = Riffer::Skills::ActivateTool.new
      result = tool.call(context: nil, name: "code-review")
      assert result.error?
      assert_includes result.content, "Skills not configured"
    end
  end
end
