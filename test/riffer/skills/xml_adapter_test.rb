# frozen_string_literal: true

require "test_helper"

describe Riffer::Skills::XmlAdapter do
  let(:adapter) { Riffer::Skills::XmlAdapter.new }
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
  end
end
