# frozen_string_literal: true

require "test_helper"

describe Riffer::Skills::FilesystemBackend do
  let(:fixtures_path) { File.expand_path("../../../fixtures/skills", __FILE__) }
  let(:extra_path) { File.expand_path("../../../fixtures/skills_extra", __FILE__) }
  let(:backend) { Riffer::Skills::FilesystemBackend.new(fixtures_path) }

  describe "#list_skills" do
    it "returns frontmatter for all discovered skills" do
      skills = backend.list_skills
      assert_equal 2, skills.length
      names = skills.map(&:name).sort
      assert_equal ["code-review", "data-analysis"], names
    end

    it "parses name and description from frontmatter" do
      skills = backend.list_skills
      code_review = skills.find { |s| s.name == "code-review" }
      assert_equal "Reviews code for quality, style, and potential issues.", code_review.description
    end

    it "merges unrecognized frontmatter keys into metadata" do
      skills = backend.list_skills
      code_review = skills.find { |s| s.name == "code-review" }
      assert_equal "test", code_review.metadata[:author]
    end

    it "returns empty metadata when no extra keys" do
      skills = backend.list_skills
      data_analysis = skills.find { |s| s.name == "data-analysis" }
      assert_equal({}, data_analysis.metadata)
    end

    it "returns empty array for non-existent path" do
      backend = Riffer::Skills::FilesystemBackend.new("/nonexistent/path")
      assert_equal [], backend.list_skills
    end

    it "scans multiple paths" do
      backend = Riffer::Skills::FilesystemBackend.new(fixtures_path, extra_path)
      skills = backend.list_skills
      assert_equal 3, skills.length
      names = skills.map(&:name).sort
      assert_equal ["code-review", "data-analysis", "summarize"], names
    end

    it "uses first-path-wins for duplicate skill names" do
      backend = Riffer::Skills::FilesystemBackend.new(fixtures_path, fixtures_path)
      skills = backend.list_skills
      names = skills.map(&:name).sort
      assert_equal ["code-review", "data-analysis"], names
    end

    it "raises when directory name does not match skill name" do
      Dir.mktmpdir do |dir|
        skill_dir = File.join(dir, "wrong-name")
        FileUtils.mkdir_p(skill_dir)
        File.write(File.join(skill_dir, "SKILL.md"), "---\nname: correct-name\ndescription: test\n---\nBody")
        backend = Riffer::Skills::FilesystemBackend.new(dir)
        error = assert_raises(Riffer::ArgumentError) { backend.list_skills }
        assert_match(/does not match name/, error.message)
      end
    end
  end

  describe "#read_skill" do
    it "returns the body without frontmatter" do
      body = backend.read_skill("code-review")
      assert_includes body, "You are a code review assistant."
      refute_includes body, "---"
      refute_includes body, "name: code-review"
    end

    it "raises for unknown skill" do
      error = assert_raises(Riffer::ArgumentError) { backend.read_skill("nonexistent") }
      assert_match(/Skill not found/, error.message)
    end

    it "auto-discovers skills on first read_skill call" do
      fresh_backend = Riffer::Skills::FilesystemBackend.new(fixtures_path)
      body = fresh_backend.read_skill("data-analysis")
      assert_includes body, "data analysis assistant"
    end
  end
end
