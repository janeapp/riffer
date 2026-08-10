# frozen_string_literal: true

require "test_helper"

# Guards the consumer-facing contract: riffer's shipped RBS (sig/generated + sig/manual) must
# resolve with riffer + stdlib alone. Optional-dependency types (provider SDKs, mcp, async, …)
# must never appear in a shipped signature — they belong in inline body assertions (see
# .agents/rbs-inline.md) or in sig/_private (which RBS skips in library mode, so it is NOT
# scanned here).
describe "shipped RBS signatures" do
  it "do not reference optional-dependency types" do
    sig_root = File.expand_path("../sig", __dir__)
    shipped_dirs = %w[generated manual]

    # Root namespaces of optional dependencies that must not leak into shipped sigs.
    forbidden_roots = %w[OpenAI Anthropic Aws MCP Async Zeitwerk Seahorse Faraday]

    # Matches the root segment of a qualified RBS type reference, allowing a leading `::` and
    # ignoring segments nested under another namespace — so `Riffer::Providers::OpenAI` has
    # root "Riffer" (not flagged) while `OpenAI::Models::Response` has root "OpenAI" (flagged).
    qualified_root = /(?<![\w:])(?:::)?([A-Z]\w*)::/

    violations = []

    shipped_dirs.each do |dir|
      Dir.glob(File.join(sig_root, dir, "**", "*.rbs")).sort.each do |path|
        File.foreach(path).with_index(1) do |line, lineno|
          code = line.sub(/#.*/, "") # strip RBS comments before scanning
          code.scan(qualified_root) do |(root)|
            next unless forbidden_roots.include?(root)

            violations << "sig/#{path.delete_prefix("#{sig_root}/")}:#{lineno}: #{root}::"
          end
        end
      end
    end

    assert_empty violations,
                 "Optional-dependency types leaked into shipped RBS. Use an inline body assertion " \
                 "instead of naming the SDK type in a `#:` signature (see .agents/rbs-inline.md):\n" +
                 violations.uniq.join("\n")
  end
end
