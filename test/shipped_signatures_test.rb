# frozen_string_literal: true

require "test_helper"

describe "shipped RBS signatures" do
  it "do not reference optional-dependency types" do
    sig_root = File.expand_path("../sig", __dir__)
    # sig/_private is excluded: RBS skips it in library mode, so it never ships.
    shipped_dirs = %w[generated manual]

    forbidden_roots = %w[OpenAI Anthropic Aws MCP Async Zeitwerk Seahorse Faraday RSpec Minitest]

    # `Riffer::Providers::OpenAI` has root "Riffer" (not flagged); `OpenAI::Models::Response`
    # has root "OpenAI" (flagged).
    qualified_root = /(?<![\w:])(?:::)?([A-Z]\w*)::/

    violations = []

    shipped_dirs.each do |dir|
      Dir.glob(File.join(sig_root, dir, "**", "*.rbs")).each do |path|
        File.foreach(path).with_index(1) do |line, lineno|
          code = line.sub(/#.*/, "")
          code.scan(qualified_root) do |(root)|
            next unless forbidden_roots.include?(root)

            violations << "sig/#{path.delete_prefix("#{sig_root}/")}:#{lineno}: #{root}::"
          end
        end
      end
    end

    assert_empty violations,
                 "Optional-dependency types leaked into shipped RBS. Use an inline body assertion " \
                 "instead of naming the SDK type in a `#:` signature (see .claude/rules/rbs-inline.md):\n" +
                 violations.uniq.join("\n")
  end
end
