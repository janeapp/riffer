# frozen_string_literal: true

require "test_helper"

describe Riffer::Skills::Frontmatter do
  describe ".parse" do
    it "parses valid SKILL.md content into frontmatter and body" do
      raw = "---\nname: code-review\ndescription: Reviews code.\n---\nYou are a reviewer."
      fm, body = Riffer::Skills::Frontmatter.parse(raw)

      assert_equal "code-review", fm.name
      assert_equal "Reviews code.", fm.description
      assert_equal({}, fm.metadata)
      assert_equal "You are a reviewer.", body
    end

    it "merges extra keys into metadata" do
      raw = "---\nname: s\ndescription: d\nauthor: test\n---\nBody"
      fm, = Riffer::Skills::Frontmatter.parse(raw)

      assert_equal({ author: "test" }, fm.metadata)
    end

    it "parses disable-model-invocation: true into the attribute" do
      raw = "---\nname: s\ndescription: d\ndisable-model-invocation: true\n---\nBody"
      fm, = Riffer::Skills::Frontmatter.parse(raw)

      assert fm.disable_model_invocation
    end

    it "does not leak disable-model-invocation into metadata" do
      raw = "---\nname: s\ndescription: d\ndisable-model-invocation: true\n---\nBody"
      fm, = Riffer::Skills::Frontmatter.parse(raw)

      assert_equal({}, fm.metadata)
    end

    it "defaults disable_model_invocation to false when absent" do
      raw = "---\nname: s\ndescription: d\n---\nBody"
      fm, = Riffer::Skills::Frontmatter.parse(raw)

      refute fm.disable_model_invocation
    end

    it "treats disable-model-invocation: false as false" do
      raw = "---\nname: s\ndescription: d\ndisable-model-invocation: false\n---\nBody"
      fm, = Riffer::Skills::Frontmatter.parse(raw)

      refute fm.disable_model_invocation
    end

    it "treats a non-boolean disable-model-invocation as false" do
      raw = "---\nname: s\ndescription: d\ndisable-model-invocation: \"true\"\n---\nBody"
      fm, = Riffer::Skills::Frontmatter.parse(raw)

      refute fm.disable_model_invocation
    end

    it "raises ArgumentError when no frontmatter delimiters are present" do
      raw = "Just plain text"
      error = assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.parse(raw) }
      assert_match(/missing YAML frontmatter/, error.message)
    end

    it "raises ArgumentError when frontmatter is a bare string" do
      raw = "---\nhello world\n---\nBody"
      error = assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.parse(raw) }
      assert_match(/must be a YAML mapping/, error.message)
    end

    it "raises ArgumentError when frontmatter is an array" do
      raw = "---\n- one\n- two\n---\nBody"
      error = assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.parse(raw) }
      assert_match(/must be a YAML mapping/, error.message)
    end

    it "raises ArgumentError when frontmatter is a number" do
      raw = "---\n42\n---\nBody"
      error = assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.parse(raw) }
      assert_match(/must be a YAML mapping/, error.message)
    end
  end

  describe "#initialize" do
    it "creates a frontmatter with valid name and description" do
      fm = Riffer::Skills::Frontmatter.new(name: "code-review", description: "Reviews code.")

      assert_equal "code-review", fm.name
      assert_equal "Reviews code.", fm.description
      assert_equal({}, fm.metadata)
    end

    it "accepts metadata" do
      fm = Riffer::Skills::Frontmatter.new(name: "s", description: "desc", metadata: { author: "test" })

      assert_equal({ author: "test" }, fm.metadata)
    end

    it "defaults disable_model_invocation to false" do
      fm = Riffer::Skills::Frontmatter.new(name: "s", description: "desc")

      refute fm.disable_model_invocation
    end

    it "accepts disable_model_invocation: true" do
      fm = Riffer::Skills::Frontmatter.new(name: "s", description: "desc", disable_model_invocation: true)

      assert fm.disable_model_invocation
    end

    it "coerces a non-true disable_model_invocation to false" do
      fm = Riffer::Skills::Frontmatter.new(name: "s", description: "desc", disable_model_invocation: "true")

      refute fm.disable_model_invocation
    end

    it "raises on empty name" do
      error = assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.new(name: "", description: "desc") }
      assert_match(/1-64 characters/, error.message)
    end

    it "raises on name with uppercase" do
      error = assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.new(name: "Code", description: "desc") }
      assert_match(/must match/, error.message)
    end

    it "raises on name starting with hyphen" do
      assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.new(name: "-skill", description: "desc") }
    end

    it "raises on name ending with hyphen" do
      assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.new(name: "skill-", description: "desc") }
    end

    it "raises on name with consecutive hyphens" do
      assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.new(name: "my--skill", description: "desc") }
    end

    it "raises on name with underscores" do
      assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.new(name: "my_skill", description: "desc") }
    end

    it "raises on name exceeding 64 characters" do
      long_name = "a" * 65
      error = assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.new(name: long_name, description: "desc") }
      assert_match(/1-64 characters/, error.message)
    end

    it "raises on non-string name" do
      error = assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.new(name: 123, description: "desc") }
      assert_match(/must be a String/, error.message)
    end

    it "raises on empty description" do
      error = assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.new(name: "s", description: "") }
      assert_match(/1-1024 characters/, error.message)
    end

    it "raises on description exceeding 1024 characters" do
      long_desc = "a" * 1025
      error = assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.new(name: "s", description: long_desc) }
      assert_match(/1-1024 characters/, error.message)
    end

    it "raises on non-string description" do
      error = assert_raises(Riffer::ArgumentError) { Riffer::Skills::Frontmatter.new(name: "s", description: 123) }
      assert_match(/must be a String/, error.message)
    end
  end
end
