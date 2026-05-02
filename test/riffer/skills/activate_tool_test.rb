# frozen_string_literal: true

require "test_helper"

describe Riffer::Skills::ActivateTool do
  let(:fixtures_path) { File.expand_path("../../../fixtures/skills", __FILE__) }
  let(:backend) { Riffer::Skills::FilesystemBackend.new(fixtures_path) }
  let(:skills) { backend.list_skills.to_h { |s| [s.name, s] } }
  let(:skills_context) { Riffer::Skills::Context.new(backend: backend, skills: skills, adapter: Riffer::Skills::MarkdownAdapter.new(skill_activate_tool: Riffer::Skills::ActivateTool)) }
  let(:context) { {skills: skills_context} }

  describe "#call" do
    it "returns skill body for a valid skill" do
      tool = Riffer::Skills::ActivateTool.new
      result = tool.call(context: context, name: "code-review")
      assert result.success?
      assert_includes result.content, "code review assistant"
    end

    it "short-circuits when the skill is already active" do
      skills_context.activate("code-review")
      tool = Riffer::Skills::ActivateTool.new
      result = tool.call(context: context, name: "code-review")
      assert result.success?
      assert_includes result.content, "already active"
      refute_includes result.content, "code review assistant"
    end

    it "returns error for unknown skill" do
      tool = Riffer::Skills::ActivateTool.new
      result = tool.call(context: context, name: "nonexistent")
      assert result.error?
      assert_includes result.content, "Unknown skill"
    end

    it "returns error when skills not configured" do
      tool = Riffer::Skills::ActivateTool.new
      result = tool.call(context: {}, name: "code-review")
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
