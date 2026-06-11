# frozen_string_literal: true

require "test_helper"

describe Riffer::Skills::MarkdownAdapter do
  let(:adapter) { Riffer::Skills::MarkdownAdapter.new(skill_activate_tool: Riffer::Skills::ActivateTool) }
  let(:skills) do
    [
      Riffer::Skills::Frontmatter.new(name: "code-review", description: "Reviews code for quality."),
      Riffer::Skills::Frontmatter.new(name: "data-analysis", description: "Analyzes datasets.")
    ]
  end

  describe "#render_catalog" do
    it "renders a Markdown skill catalog" do
      output = adapter.render_catalog(skills)
      assert_includes output, "## Available Skills"
      assert_includes output, "skill_activate"
      assert_includes output, "- **code-review**: Reviews code for quality."
      assert_includes output, "- **data-analysis**: Analyzes datasets."
    end

    it "uses the configured skill_activate_tool name in the prompt" do
      custom = Class.new(Riffer::Tool) do
        identifier "custom_activate"
        description "Custom"
        def call(context:)
          text("ok")
        end
      end
      custom_adapter = Riffer::Skills::MarkdownAdapter.new(skill_activate_tool: custom)
      output = custom_adapter.render_catalog(skills)
      assert_includes output, "`custom_activate`"
    end

    it "instructs the model not to re-activate skills already in context" do
      assert_includes adapter.render_catalog(skills), "instead of activating the skill again"
    end
  end

  describe "#render_activation" do
    it "wraps the body in skill_content tags" do
      output = adapter.render_activation(skills.first, "The body.")
      assert_equal %(<skill_content name="code-review">\nThe body.\n</skill_content>), output
    end
  end
end
