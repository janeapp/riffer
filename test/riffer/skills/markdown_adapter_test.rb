# frozen_string_literal: true

require "test_helper"

describe Riffer::Skills::MarkdownAdapter do
  let(:adapter) { Riffer::Skills::MarkdownAdapter.new }
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
  end
end
