# frozen_string_literal: true

require "test_helper"

describe Riffer::Skills::XmlAdapter do
  let(:adapter) { Riffer::Skills::XmlAdapter.new(skill_activate_tool: Riffer::Skills::ActivateTool) }
  let(:skills) do
    [
      Riffer::Skills::Frontmatter.new(name: "code-review", description: "Reviews code for quality."),
      Riffer::Skills::Frontmatter.new(name: "data-analysis", description: "Analyzes datasets.")
    ]
  end

  describe "#render_catalog" do
    it "renders an XML skill catalog" do
      output = adapter.render_catalog(skills)
      assert_includes output, "<available_skills>"
      assert_includes output, "</available_skills>"
      assert_includes output, "<name>code-review</name>"
      assert_includes output, "<description>Reviews code for quality.</description>"
      assert_includes output, "<name>data-analysis</name>"
      assert_includes output, "skill_activate"
    end

    it "escapes XML-unsafe characters in descriptions" do
      skill = Riffer::Skills::Frontmatter.new(name: "compare", description: "Compares A & B using <templates>")
      output = adapter.render_catalog([skill])
      assert_includes output, "<description>Compares A &amp; B using &lt;templates&gt;</description>"
    end

    it "uses the configured skill_activate_tool name in the prompt" do
      custom = Class.new(Riffer::Tool) do
        identifier "custom_activate"
        description "Custom"
        def call(context:)
          text("ok")
        end
      end
      custom_adapter = Riffer::Skills::XmlAdapter.new(skill_activate_tool: custom)
      output = custom_adapter.render_catalog(skills)
      assert_includes output, "`custom_activate`"
    end
  end
end
