# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "stringio"

# Offline stand-ins for the provider's command-runner seam (no subprocess).
class FakeClaudeCodeStatus
  attr_reader :exitstatus

  def initialize(exitstatus)
    @exitstatus = exitstatus
  end

  def success?
    @exitstatus.zero?
  end
end

class FakeClaudeCodeRunner
  attr_reader :calls
  attr_reader :stream_calls

  # +stdouts+ serves one stdout per call, in order, for tests that interleave
  # calls with different envelopes on one provider instance. +lines:+ is raw
  # NDJSON text served by +#stream+, split and yielded one line at a time.
  def initialize(stdout: "", stderr: "", exitstatus: 0, stdouts: nil, lines: "", stream_stderr: "",
                 stream_exitstatus: 0)
    @stdout = stdout
    @stdouts = stdouts
    @stderr = stderr
    @exitstatus = exitstatus
    @lines = lines
    @stream_stderr = stream_stderr
    @stream_exitstatus = stream_exitstatus
    @calls = []
    @stream_calls = []
  end

  def call(argv, env:, stdin:, chdir:, timeout:)
    @calls << { argv: argv, env: env, stdin: stdin, chdir: chdir, timeout: timeout }
    stdout = @stdouts ? @stdouts.fetch(@calls.length - 1) : @stdout
    [stdout, @stderr, FakeClaudeCodeStatus.new(@exitstatus)]
  end

  def stream(argv, env:, stdin:, chdir:, timeout:, &)
    @stream_calls << { argv: argv, env: env, stdin: stdin, chdir: chdir, timeout: timeout }
    @lines.each_line(&)
    [@stream_stderr, FakeClaudeCodeStatus.new(@stream_exitstatus)]
  end
end

# Derives a session id from stdin content rather than serving calls in a fixed
# order, so two threads driving independent conversations get consistent,
# distinguishable envelopes regardless of interleaving.
class TrackingClaudeCodeRunner
  attr_reader :calls

  def initialize(session_id_for:)
    @session_id_for = session_id_for
    @calls = []
    @mutex = Mutex.new
  end

  def call(argv, env:, stdin:, chdir:, timeout:)
    session_id = @session_id_for.call(stdin)
    envelope = {
      is_error: false, stop_reason: "end_turn", session_id: session_id,
      result: "reply to #{stdin}", usage: { input_tokens: 1, output_tokens: 1 }, total_cost_usd: 0.001,
    }
    @mutex.synchronize { @calls << { argv: argv, stdin: stdin, session_id: session_id } }
    [JSON.generate(envelope), "", FakeClaudeCodeStatus.new(0)]
  end
end

describe Riffer::Providers::ClaudeCode do
  let(:model) { "claude-haiku-4-5-20251001" }
  let(:runner) { FakeClaudeCodeRunner.new(stdout: fixture("success_text.json")) }
  let(:provider) { build_provider(runner: runner) }

  before { @tmpdir = Dir.mktmpdir("claude-code-test") }

  after do
    FileUtils.remove_entry(@tmpdir)
    Riffer.config.claude_code.each_pair { |name, _| Riffer.config.claude_code[name] = nil }
  end

  def fixture(name)
    File.read(File.expand_path("../../fixtures/claude_code/#{name}", __dir__))
  end

  def fake_binary
    @fake_binary ||= begin
      path = File.join(@tmpdir, "claude")
      File.write(path, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, path)
      path
    end
  end

  def build_provider(runner:, **config_overrides)
    Riffer.config.claude_code.binary = fake_binary
    Riffer.config.claude_code.client = runner
    config_overrides.each { |key, value| Riffer.config.claude_code[key] = value }
    Riffer::Providers::ClaudeCode.new
  end

  def argv_pairs(argv)
    argv.each_cons(2).to_a
  end

  describe ".semconv_provider_name" do
    it "returns the semconv well-known value" do
      expect(Riffer::Providers::ClaudeCode.semconv_provider_name).must_equal "claude_code"
    end
  end

  describe ".skills_adapter" do
    it "returns XmlAdapter" do
      expect(Riffer::Providers::ClaudeCode.skills_adapter).must_equal Riffer::Skills::XmlAdapter
    end
  end

  describe "repository registration" do
    it "resolves :claude_code to the ClaudeCode provider class" do
      expect(Riffer::Providers::Repository.find(:claude_code)).must_equal Riffer::Providers::ClaudeCode
    end
  end

  describe "#initialize" do
    it "creates the provider" do
      expect(Riffer::Providers::ClaudeCode.new).must_be_instance_of Riffer::Providers::ClaudeCode
    end

    it "takes no arguments" do
      expect { Riffer::Providers::ClaudeCode.new(binary: "claude") }.must_raise ArgumentError
    end
  end

  describe "client resolution" do
    it "builds a Client when no client is configured" do
      client = Riffer::Providers::ClaudeCode.new.send(:client)

      expect(client).must_be_instance_of Riffer::Providers::ClaudeCode::Client
    end

    it "memoizes the client it builds" do
      claude_code = Riffer::Providers::ClaudeCode.new

      expect(claude_code.send(:client)).must_be_same_as claude_code.send(:client)
    end

    it "uses the configured client" do
      expect(provider.send(:client)).must_be_same_as runner
    end

    it "resolves a configured client Proc on every call" do
      calls = 0
      Riffer.config.claude_code.client = -> { calls += 1 }

      Riffer::Providers::ClaudeCode.new.tap { |cc| cc.send(:client) }.send(:client)

      expect(calls).must_equal 2
    end
  end

  describe "plain text generation" do
    it "returns the CLI result as assistant content" do
      assistant = provider.generate_text(prompt: "say ok", model: model)

      expect(assistant.content).must_equal "ok"
      expect(assistant.tool_calls).must_equal []
      expect(assistant.structured_output).must_be_nil
    end

    it "maps end_turn to a :stop finish reason" do
      assistant = provider.generate_text(prompt: "say ok", model: model)

      expect(assistant.finish_reason).must_equal :stop
    end

    it "sends the prompt on stdin and runs with the configured timeout" do
      provider.generate_text(prompt: "say ok", model: model)

      call = runner.calls.fetch(0)

      expect(call[:stdin]).must_equal "say ok"
      expect(call[:timeout]).must_equal 120
    end

    it "defaults cwd to a private per-instance directory, reused across calls" do
      provider.generate_text(prompt: "one", model: model)
      provider.generate_text(prompt: "two", model: model)

      first_cwd = runner.calls.fetch(0)[:chdir]
      second_cwd = runner.calls.fetch(1)[:chdir]

      expect(first_cwd).must_equal second_cwd
      expect(first_cwd).wont_equal Dir.tmpdir
      expect(File.directory?(first_cwd)).must_equal true
    end

    it "honors a configured cwd instead of the private default" do
      build_provider(runner: runner, cwd: @tmpdir).generate_text(prompt: "hi", model: model)

      expect(runner.calls.fetch(0)[:chdir]).must_equal @tmpdir
    end

    it "shares one process-wide private cwd across separate provider instances" do
      other_runner = FakeClaudeCodeRunner.new(stdout: fixture("success_text.json"))
      build_provider(runner: runner).generate_text(prompt: "one", model: model)
      build_provider(runner: other_runner).generate_text(prompt: "two", model: model)

      first_cwd = runner.calls.fetch(0)[:chdir]
      second_cwd = other_runner.calls.fetch(0)[:chdir]

      expect(first_cwd).must_equal second_cwd
    end

    it "creates the private cwd with mode 0700" do
      provider.generate_text(prompt: "hi", model: model)

      private_cwd = runner.calls.fetch(0)[:chdir]

      expect(File.stat(private_cwd).mode & 0o777).must_equal 0o700
    end

    it "sums input_tokens across the base, cache-write, and cache-read buckets" do
      usage = provider.generate_text(prompt: "say ok", model: model).token_usage

      expect(usage.input_tokens).must_equal(9 + 9012 + 17_900)
    end

    it "extracts output_tokens" do
      usage = provider.generate_text(prompt: "say ok", model: model).token_usage

      expect(usage.output_tokens).must_equal 50
    end

    it "extracts the cache-write and cache-read buckets separately" do
      usage = provider.generate_text(prompt: "say ok", model: model).token_usage

      expect(usage.cache_write_tokens).must_equal 9012
      expect(usage.cache_read_tokens).must_equal 17_900
    end

    it "uses the CLI-computed cost" do
      usage = provider.generate_text(prompt: "say ok", model: model).token_usage

      expect(usage.cost).must_be_within_delta(0.020072999999999997, 1e-9)
    end
  end

  describe "argv construction" do
    it "starts argv with the resolved binary path" do
      provider.generate_text(prompt: "say ok", model: model)

      expect(runner.calls.fetch(0)[:argv].first).must_equal fake_binary
    end

    it "passes -p for headless mode" do
      provider.generate_text(prompt: "say ok", model: model)

      expect(runner.calls.fetch(0)[:argv]).must_include "-p"
    end

    it "requests JSON output format for buffered generation" do
      provider.generate_text(prompt: "say ok", model: model)

      expect(argv_pairs(runner.calls.fetch(0)[:argv])).must_include ["--output-format", "json"]
    end

    it "passes an empty --allowedTools and --tools by default, disabling the CLI's built-in tools" do
      provider.generate_text(prompt: "say ok", model: model)

      pairs = argv_pairs(runner.calls.fetch(0)[:argv])

      expect(pairs).must_include ["--allowedTools", ""]
      expect(pairs).must_include ["--tools", ""]
    end

    it "passes the configured allowed_tools joined by commas to both --allowedTools and --tools" do
      build_provider(runner: runner, allowed_tools: %w[Bash Read]).generate_text(prompt: "hi", model: model)

      pairs = argv_pairs(runner.calls.fetch(0)[:argv])

      expect(pairs).must_include ["--allowedTools", "Bash,Read"]
      expect(pairs).must_include ["--tools", "Bash,Read"]
    end

    it "strips permission-rule parens from --tools while keeping the full rule on --allowedTools" do
      build_provider(runner: runner, allowed_tools: ["Bash(git *)", "Read"]).generate_text(prompt: "hi", model: model)

      pairs = argv_pairs(runner.calls.fetch(0)[:argv])

      expect(pairs).must_include ["--allowedTools", "Bash(git *),Read"]
      expect(pairs).must_include ["--tools", "Bash,Read"]
    end

    it "passes the configured --setting-sources" do
      provider.generate_text(prompt: "say ok", model: model)

      expect(argv_pairs(runner.calls.fetch(0)[:argv])).must_include ["--setting-sources", "project"]
    end

    it "honors a custom setting_sources" do
      build_provider(runner: runner, setting_sources: "user,project").generate_text(prompt: "hi", model: model)

      expect(argv_pairs(runner.calls.fetch(0)[:argv])).must_include ["--setting-sources", "user,project"]
    end

    it "passes --model with the resolved model id" do
      provider.generate_text(prompt: "say ok", model: model)

      expect(argv_pairs(runner.calls.fetch(0)[:argv])).must_include ["--model", model]
    end

    it "omits --model for the claude_code/default sentinel" do
      provider.generate_text(prompt: "hi", model: "default")

      expect(runner.calls.fetch(0)[:argv]).wont_include "--model"
    end

    it "falls back to default_model for direct provider use" do
      build_provider(runner: runner, default_model: model).generate_text(prompt: "hi")

      expect(argv_pairs(runner.calls.fetch(0)[:argv])).must_include ["--model", model]
    end

    it "assigns a --session-id on the first turn when session_persistence is enabled (the default)" do
      provider.generate_text(prompt: "say ok", model: model)

      argv = runner.calls.fetch(0)[:argv]
      session_id = argv_pairs(argv).find { |pair| pair.first == "--session-id" }&.last

      expect(argv).wont_include "--no-session-persistence"
      expect(session_id).must_match(/\A[0-9a-f-]{36}\z/)
    end

    it "passes --no-session-persistence and omits --session-id when session_persistence: false" do
      build_provider(runner: runner, session_persistence: false).generate_text(prompt: "say ok", model: model)

      argv = runner.calls.fetch(0)[:argv]

      expect(argv).must_include "--no-session-persistence"
      expect(argv).wont_include "--session-id"
    end

    it "keeps the prompt off argv (it rides stdin)" do
      provider.generate_text(prompt: "say ok", model: model)

      expect(runner.calls.fetch(0)[:argv]).wont_include "say ok"
    end

    it "omits --json-schema on plain-text calls" do
      provider.generate_text(prompt: "say ok", model: model)

      expect(runner.calls.fetch(0)[:argv]).wont_include "--json-schema"
    end

    it "passes the system message via --append-system-prompt by default" do
      provider.generate_text(prompt: "hi", system: "Be terse", model: model)

      expect(argv_pairs(runner.calls.fetch(0)[:argv])).must_include ["--append-system-prompt", "Be terse"]
    end

    it "passes the system message via --system-prompt in :replace mode" do
      build_provider(runner: runner, system_prompt_mode: :replace).generate_text(prompt: "hi", system: "Be terse",
                                                                                 model: model,)

      argv = runner.calls.fetch(0)[:argv]

      expect(argv_pairs(argv)).must_include ["--system-prompt", "Be terse"]
      expect(argv).wont_include "--append-system-prompt"
    end

    it "omits the system prompt flag without a system message" do
      provider.generate_text(prompt: "hi", model: model)

      argv = runner.calls.fetch(0)[:argv]

      expect(argv).wont_include "--append-system-prompt"
      expect(argv).wont_include "--system-prompt"
    end
  end

  describe "structured output" do
    let(:runner) { FakeClaudeCodeRunner.new(stdout: fixture("success_structured.json")) }
    let(:structured_output) do
      params = Riffer::Params.new
      params.required(:ok, Riffer::Params::Boolean)
      Riffer::Agent::StructuredOutput.new(params)
    end

    it "passes the strict schema as an inline --json-schema JSON string" do
      provider.generate_text(prompt: "hi", model: model, structured_output: structured_output)

      schema_json = JSON.generate(structured_output.json_schema(strict: true))

      expect(argv_pairs(runner.calls.fetch(0)[:argv])).must_include ["--json-schema", schema_json]
    end

    it "round-trips the result JSON string into structured_output" do
      assistant = provider.generate_text(prompt: "hi", model: model, structured_output: structured_output)

      expect(assistant.content).must_equal "{\"ok\":true}"
      expect(assistant.structured_output).must_equal({ ok: true })
    end

    it "maps the CLI's tool_use stop reason to :stop when structured output is requested" do
      assistant = provider.generate_text(prompt: "hi", model: model, structured_output: structured_output)

      expect(assistant.finish_reason).must_equal :stop
    end

    it "keeps tool_use mapped to :tool_calls without structured output" do
      envelope = JSON.parse(fixture("success_text.json"))
      envelope["stop_reason"] = "tool_use"
      tool_use_runner = FakeClaudeCodeRunner.new(stdout: JSON.generate(envelope))

      assistant = build_provider(runner: tool_use_runner).generate_text(prompt: "hi", model: model)

      expect(assistant.finish_reason).must_equal :tool_calls
    end

    it "does not leak schema mode across calls via unconsumed stream enumerators" do
      # generate_text runs its call eagerly (the stream is lazy), so the
      # runner serves success_text to it via #call and success_structured to
      # the stream via #stream — separate call/stream tracking, unlike
      # #call's ordered `stdouts:`.
      interleaved_runner = FakeClaudeCodeRunner.new(
        stdout: fixture("success_text.json"),
        lines: "#{fixture('success_structured.json').strip}\n",
      )
      interleaved_provider = build_provider(runner: interleaved_runner)

      stream = interleaved_provider.stream_text(prompt: "hi", model: model, structured_output: structured_output)
      interleaved_provider.generate_text(prompt: "hi", model: model)
      finish = stream.to_a.find { |event| event.is_a?(Riffer::StreamEvents::FinishReasonDone) }

      expect(finish.finish_reason).must_equal :stop
    end
  end

  describe "auth env scrubbing" do
    let(:scrubbed_var_names) { Riffer::Providers::ClaudeCode::DEFAULT_SCRUB_ENV }

    before do
      @original_env = scrubbed_var_names.to_h { |name| [name, ENV.fetch(name, nil)] }
      scrubbed_var_names.each { |name| ENV[name] = "test-value" }
    end

    after do
      @original_env.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
    end

    it "scrubs the auth-precedence vars in :subscription mode" do
      provider.generate_text(prompt: "hi", model: model)

      env = runner.calls.fetch(0)[:env]

      expect(env.keys & scrubbed_var_names).must_equal []
    end

    it "retains the env untouched in :api_key mode" do
      build_provider(runner: runner, auth: :api_key).generate_text(prompt: "hi", model: model)

      env = runner.calls.fetch(0)[:env]

      expect(scrubbed_var_names.all? { |name| env[name] == "test-value" }).must_equal true
    end

    it "scrubs only the configured scrub_env list" do
      build_provider(runner: runner, scrub_env: ["ANTHROPIC_API_KEY"]).generate_text(prompt: "hi", model: model)

      env = runner.calls.fetch(0)[:env]

      expect(env.key?("ANTHROPIC_API_KEY")).must_equal false
      expect(env["ANTHROPIC_AUTH_TOKEN"]).must_equal "test-value"
    end
  end

  describe "failure handling" do
    it "raises on a non-zero exit, surfacing the CLI's error detail" do
      failing = FakeClaudeCodeRunner.new(stdout: fixture("error_api.json"), exitstatus: 1)

      error = assert_raises(Riffer::Error) { build_provider(runner: failing).generate_text(prompt: "hi", model: model) }

      expect(error.message).must_match(/exit 1.*api_error_status=404.*issue with the selected model/m)
    end

    it "raises on is_error: true even when the exit code is zero and subtype is success" do
      failing = FakeClaudeCodeRunner.new(stdout: fixture("error_api.json"), exitstatus: 0)

      error = assert_raises(Riffer::Error) { build_provider(runner: failing).generate_text(prompt: "hi", model: model) }

      expect(error.message).must_match(/claude CLI call failed/)
    end

    it "raises on unparseable stdout, including stderr in the message" do
      garbled = FakeClaudeCodeRunner.new(stdout: "not json", stderr: "boom", exitstatus: 0)

      error = assert_raises(Riffer::Error) { build_provider(runner: garbled).generate_text(prompt: "hi", model: model) }

      expect(error.message).must_match(/unparseable output.*boom/m)
    end

    it "raises on first use when the configured binary does not exist" do
      Riffer.config.claude_code.binary = File.join(@tmpdir, "missing-claude")

      error = assert_raises(Riffer::Error) { Riffer::Providers::ClaudeCode.new.generate_text(prompt: "hi", model: model) }

      expect(error.message).must_match(/not found or not executable/)
    end

    it "raises on first use when the configured binary is not on PATH" do
      Riffer.config.claude_code.binary = "definitely-not-a-real-claude-binary"

      error = assert_raises(Riffer::Error) { Riffer::Providers::ClaudeCode.new.generate_text(prompt: "hi", model: model) }

      expect(error.message).must_match(/not found or not executable/)
    end
  end

  describe "fail-loud input contract" do
    it "rejects riffer tools" do
      error = assert_raises(Riffer::ArgumentError) do
        provider.generate_text(prompt: "hi", model: model, tools: [Class.new(Riffer::Tool)])
      end

      expect(error.message).must_match(/does not support riffer tools/)
    end

    it "rejects assistant history messages when session_persistence: false" do
      messages = [{ role: "user", content: "hi" }, { role: "assistant", content: "hello" },
                  { role: "user", content: "again" },]

      error = assert_raises(Riffer::ArgumentError) do
        build_provider(runner: runner, session_persistence: false).generate_text(messages: messages, model: model)
      end

      expect(error.message).must_match(/session_persistence.*assistant/m)
    end

    it "raises a fingerprint-miss error for fabricated assistant history under default session_persistence" do
      messages = [{ role: "user", content: "hi" }, { role: "assistant", content: "hello" },
                  { role: "user", content: "again" },]

      error = assert_raises(Riffer::ArgumentError) { provider.generate_text(messages: messages, model: model) }

      expect(error.message).must_match(/cannot replay fabricated history/)
    end

    it "rejects assistant history messages carrying tool calls" do
      first = provider.generate_text(prompt: "hi", model: model)
      messages = [
        { role: "user", content: "hi" },
        {
          role: "assistant", content: first.content,
          tool_calls: [{ call_id: "call_1", name: "calc", arguments: {} }],
        },
        { role: "user", content: "again" },
      ]

      error = assert_raises(Riffer::ArgumentError) { provider.generate_text(messages: messages, model: model) }

      expect(error.message).must_match(/cannot resume history containing tool calls/)
    end

    it "rejects tool result messages" do
      messages = [{ role: "user", content: "hi" },
                  { role: "tool", content: "42", tool_call_id: "call_1", name: "calc" },]

      error = assert_raises(Riffer::ArgumentError) { provider.generate_text(messages: messages, model: model) }

      expect(error.message).must_match(/does not support tool messages/)
    end

    it "rejects a missing model, pointing at the sentinel" do
      error = assert_raises(Riffer::ArgumentError) { provider.generate_text(prompt: "hi") }

      expect(error.message).must_match(%r{requires an explicit model.*claude_code/default}m)
    end

    it "rejects a model segment containing shell metacharacters" do
      error = assert_raises(Riffer::ArgumentError) { provider.generate_text(prompt: "hi", model: "haiku; rm -rf /") }

      expect(error.message).must_match(/invalid claude_code model segment/)
    end

    it "allows a bracketed context-window model variant" do
      provider.generate_text(prompt: "hi", model: "sonnet[1m]")

      expect(argv_pairs(runner.calls.fetch(0)[:argv])).must_include ["--model", "sonnet[1m]"]
    end

    it "allows a Vertex model id containing @" do
      provider.generate_text(prompt: "hi", model: "claude-sonnet-4-5@20250929")

      expect(argv_pairs(runner.calls.fetch(0)[:argv])).must_include ["--model", "claude-sonnet-4-5@20250929"]
    end

    it "allows a Bedrock model id containing . and :" do
      provider.generate_text(prompt: "hi", model: "anthropic.claude-sonnet-4-5-20250929-v1:0")

      expect(argv_pairs(runner.calls.fetch(0)[:argv])).must_include(
        ["--model", "anthropic.claude-sonnet-4-5-20250929-v1:0"],
      )
    end

    it "rejects a model segment containing whitespace" do
      error = assert_raises(Riffer::ArgumentError) { provider.generate_text(prompt: "hi", model: "sonnet 4") }

      expect(error.message).must_match(/invalid claude_code model segment/)
    end

    it "rejects a model segment with a leading dash" do
      error = assert_raises(Riffer::ArgumentError) { provider.generate_text(prompt: "hi", model: "-model") }

      expect(error.message).must_match(/invalid claude_code model segment/)
    end
  end

  describe "pricing fallback" do
    after { Riffer.instance_variable_set(:@config, Riffer::Config.new) }

    it "applies consumer pricing when the envelope has no total_cost_usd" do
      envelope = JSON.parse(fixture("success_text.json"))
      envelope.delete("total_cost_usd")
      unpriced_runner = FakeClaudeCodeRunner.new(stdout: JSON.generate(envelope))
      Riffer.config.pricing.set("claude_code/#{model}", input: 1.0, output: 5.0, cache_read: 0.1, cache_write: 1.25)

      usage = build_provider(runner: unpriced_runner).generate_text(prompt: "hi", model: model).token_usage

      # uncached 9 * 1.0 + cache_read 17900 * 0.1 + cache_write 9012 * 1.25 + output 50 * 5.0, per million
      expect(usage.cost).must_be_within_delta(0.013314, 1e-9)
    end

    it "prefers the envelope cost over consumer pricing when both exist" do
      Riffer.config.pricing.set("claude_code/#{model}", input: 1.0, output: 5.0)

      usage = provider.generate_text(prompt: "hi", model: model).token_usage

      expect(usage.cost).must_be_within_delta(0.020072999999999997, 1e-9)
    end
  end

  describe "incremental streaming" do
    let(:stream_runner) { FakeClaudeCodeRunner.new(lines: fixture("stream_text.ndjson")) }
    let(:stream_provider) { build_provider(runner: stream_runner) }

    it "emits the events in order: reasoning, text, finish reason, then token usage" do
      events = stream_provider.stream_text(prompt: "count to 5", model: model).to_a

      expect(events.map(&:class)).must_equal([
                                               Riffer::StreamEvents::ReasoningDelta,
                                               Riffer::StreamEvents::ReasoningDelta,
                                               Riffer::StreamEvents::ReasoningDelta,
                                               Riffer::StreamEvents::ReasoningDelta,
                                               Riffer::StreamEvents::ReasoningDone,
                                               Riffer::StreamEvents::TextDelta,
                                               Riffer::StreamEvents::TextDone,
                                               Riffer::StreamEvents::FinishReasonDone,
                                               Riffer::StreamEvents::TokenUsageDone,
                                             ])
    end

    it "accumulates the full reasoning text onto ReasoningDone" do
      events = stream_provider.stream_text(prompt: "count to 5", model: model).to_a
      reasoning_done = events.find { |event| event.is_a?(Riffer::StreamEvents::ReasoningDone) }

      expect(reasoning_done.part.text).must_equal(
        "The user is asking me to count from 1 to 5 in words. This is a straightforward request.\n\n" \
        "1 = One\n2 = Two\n3 = Three\n4 = Four\n5 = Five\n\nThis is a simple task, no tools needed.",
      )
    end

    it "does not bleed an earlier thinking block's text into a later block at the same index" do
      lines = [
        { type: "stream_event",
          event: { type: "content_block_start", index: 0, content_block: { type: "thinking" } }, },
        { type: "stream_event",
          event: { type: "content_block_delta", index: 0, delta: { type: "thinking_delta", thinking: "first" } }, },
        { type: "stream_event", event: { type: "content_block_stop", index: 0 } },
        { type: "stream_event",
          event: { type: "content_block_start", index: 0, content_block: { type: "thinking" } }, },
        { type: "stream_event",
          event: { type: "content_block_delta", index: 0, delta: { type: "thinking_delta", thinking: "second" } }, },
        { type: "stream_event", event: { type: "content_block_stop", index: 0 } },
        { is_error: false, stop_reason: "end_turn", session_id: "s", total_cost_usd: 0.0, usage: {}, result: "ok",
          type: "result", },
      ].map { |line| JSON.generate(line) }.join("\n")
      restarted_index_runner = FakeClaudeCodeRunner.new(lines: "#{lines}\n")

      events = build_provider(runner: restarted_index_runner).stream_text(prompt: "hi", model: model).to_a
      reasoning_dones = events.grep(Riffer::StreamEvents::ReasoningDone)

      expect(reasoning_dones.map { |event| event.part.text }).must_equal %w[first second]
    end

    it "emits the full reply text on TextDone" do
      events = stream_provider.stream_text(prompt: "count to 5", model: model).to_a
      text_done = events.find { |event| event.is_a?(Riffer::StreamEvents::TextDone) }

      expect(text_done.content).must_equal "One, two, three, four, five."
    end

    it "reports the normalized and raw finish reason" do
      events = stream_provider.stream_text(prompt: "count to 5", model: model).to_a
      finish = events.find { |event| event.is_a?(Riffer::StreamEvents::FinishReasonDone) }

      expect(finish.finish_reason).must_equal :stop
      expect(finish.raw_finish_reason).must_equal "end_turn"
    end

    it "reports token usage from the terminal result event" do
      events = stream_provider.stream_text(prompt: "count to 5", model: model).to_a
      usage = events.find { |event| event.is_a?(Riffer::StreamEvents::TokenUsageDone) }.token_usage

      expect(usage.input_tokens).must_equal(9 + 2642 + 21_937)
      expect(usage.output_tokens).must_equal 82
      expect(usage.cost).must_be_within_delta(0.0078967, 1e-9)
    end

    it "uses --output-format stream-json --include-partial-messages --verbose" do
      stream_provider.stream_text(prompt: "count to 5", model: model).to_a

      argv = stream_runner.stream_calls.fetch(0)[:argv]

      expect(argv_pairs(argv)).must_include ["--output-format", "stream-json"]
      expect(argv).must_include "--include-partial-messages"
      expect(argv).must_include "--verbose"
    end

    it "never passes the buffered --output-format json to a streaming call" do
      stream_provider.stream_text(prompt: "count to 5", model: model).to_a

      expect(stream_runner.stream_calls.fetch(0)[:argv]).wont_include "json"
    end

    it "raises on a mid-stream error result (is_error: true)" do
      failing_runner = FakeClaudeCodeRunner.new(lines: "#{fixture('error_api.json').strip}\n")

      error = assert_raises(Riffer::Error) do
        build_provider(runner: failing_runner).stream_text(prompt: "hi", model: model).to_a
      end

      expect(error.message).must_match(/claude CLI call failed/)
    end

    it "raises Riffer::Error on an unparseable NDJSON line" do
      garbled_runner = FakeClaudeCodeRunner.new(lines: "not json\n")

      error = assert_raises(Riffer::Error) do
        build_provider(runner: garbled_runner).stream_text(prompt: "hi", model: model).to_a
      end

      expect(error.message).must_match(/unparseable line/)
    end

    it "raises Riffer::IncompleteStreamError when the stream ends without a result event" do
      lines_without_result = fixture("stream_text.ndjson").each_line.reject do |line|
        JSON.parse(line)["type"] == "result"
      end.join
      no_result_runner = FakeClaudeCodeRunner.new(lines: lines_without_result)

      error = assert_raises(Riffer::IncompleteStreamError) do
        build_provider(runner: no_result_runner).stream_text(prompt: "hi", model: model).to_a
      end

      expect(error.message).must_match(/ended without a result event/)
    end

    it "falls back to the result string for TextDone when no text deltas arrive (structured output)" do
      params = Riffer::Params.new
      params.required(:ok, Riffer::Params::Boolean)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      fallback_runner = FakeClaudeCodeRunner.new(lines: "#{fixture('success_structured.json').strip}\n")

      events = build_provider(runner: fallback_runner).
        stream_text(prompt: "hi", model: model, structured_output: structured_output).to_a

      text_done = events.find { |event| event.is_a?(Riffer::StreamEvents::TextDone) }
      finish = events.find { |event| event.is_a?(Riffer::StreamEvents::FinishReasonDone) }

      expect(text_done.content).must_equal "{\"ok\":true}"
      expect(finish.finish_reason).must_equal :stop # tool_use remapped because structured_output is present
    end

    it "resumes a session when streaming a second turn" do
      two_turn_runner = FakeClaudeCodeRunner.new(stdout: fixture("success_text.json"),
                                                 lines: fixture("stream_text.ndjson"),)
      multi_turn_provider = build_provider(runner: two_turn_runner)
      first = multi_turn_provider.generate_text(prompt: "hi", model: model)
      messages = [{ role: "user", content: "hi" }, { role: "assistant", content: first.content },
                  { role: "user", content: "again" },]

      multi_turn_provider.stream_text(messages: messages, model: model).to_a

      stream_call = two_turn_runner.stream_calls.fetch(0)

      expect(argv_pairs(stream_call[:argv])).must_include ["--resume", "00000000-0000-4000-8000-000000000001"]
      expect(stream_call[:stdin]).must_equal "again"
    end

    it "emits exactly one authoritative TextDone from the terminal result event, even with multiple text blocks" do
      multi_block_runner = FakeClaudeCodeRunner.new(lines: fixture("stream_text_multi_block.ndjson"))

      events = build_provider(runner: multi_block_runner).stream_text(prompt: "hi", model: model).to_a
      text_dones = events.grep(Riffer::StreamEvents::TextDone)

      expect(text_dones.size).must_equal 1
      expect(text_dones.first.content).must_equal "Hello, world!"
    end

    it "does not emit a separate TextDone per content block" do
      multi_block_runner = FakeClaudeCodeRunner.new(lines: fixture("stream_text_multi_block.ndjson"))

      events = build_provider(runner: multi_block_runner).stream_text(prompt: "hi", model: model).to_a

      expect(events.map(&:class)).must_equal([
                                               Riffer::StreamEvents::TextDelta,
                                               Riffer::StreamEvents::TextDelta,
                                               Riffer::StreamEvents::TextDone,
                                               Riffer::StreamEvents::FinishReasonDone,
                                               Riffer::StreamEvents::TokenUsageDone,
                                             ])
    end

    it "keeps a reconstructed multi-block reply resumable as turn-2 history" do
      two_turn_runner = FakeClaudeCodeRunner.new(
        stdout: fixture("success_text.json"), lines: fixture("stream_text_multi_block.ndjson"),
      )
      multi_turn_provider = build_provider(runner: two_turn_runner)
      events = multi_turn_provider.stream_text(prompt: "hi", model: model).to_a
      # Mirrors Riffer::Tracing::StreamRecorder#record: last TextDone wins.
      reconstructed = events.reverse.find { |event| event.is_a?(Riffer::StreamEvents::TextDone) }.content
      messages = [
        { role: "user", content: "hi" },
        { role: "assistant", content: reconstructed },
        { role: "user", content: "again" },
      ]

      multi_turn_provider.generate_text(messages: messages, model: model)

      expect(argv_pairs(two_turn_runner.calls.fetch(0)[:argv])).must_include ["--resume", "multi-block-session"]
    end
  end

  describe "Client#call" do
    let(:default_runner) { Riffer::Providers::ClaudeCode::Client.new }

    it "returns stdout, stderr, and status, feeding the prompt on stdin" do
      stdout, stderr, status = default_runner.call(
        ["/bin/sh", "-c", "cat; echo err >&2"],
        env: { "PATH" => "/usr/bin:/bin" }, stdin: "hello", chdir: Dir.tmpdir, timeout: 10,
      )

      expect(stdout).must_equal "hello"
      expect(stderr).must_equal "err\n"
      expect(status.success?).must_equal true
    end

    it "kills the child and raises Riffer::TimeoutError on deadline expiry" do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      error = assert_raises(Riffer::TimeoutError) do
        default_runner.call(["/bin/sleep", "10"], env: { "PATH" => "/usr/bin:/bin" }, stdin: "", chdir: Dir.tmpdir,
                                                  timeout: 0.2,)
      end

      expect(error.message).must_match(/timed out after 0.2 seconds/)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).must_be :<, 5
    end

    it "times out when a grandchild inherits the pipes after the child exits within the deadline" do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      error = assert_raises(Riffer::TimeoutError) do
        # The shell exits immediately, but the backgrounded sleep inherits the
        # stdout/stderr pipes and would hold the drains open for 2s.
        default_runner.call(["/bin/sh", "-c", "sleep 2 & exit 0"], env: { "PATH" => "/usr/bin:/bin" }, stdin: "",
                                                                   chdir: Dir.tmpdir, timeout: 0.3,)
      end

      expect(error.message).must_match(/timed out after 0\.3 seconds/)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).must_be :<, 1.5
    end

    it "wraps spawn failures in Riffer::Error" do
      original_verbose = $VERBOSE
      original_popen3 = Open3.method(:popen3)
      $VERBOSE = nil # silences Ruby's "method redefined" warning for this deliberate stub
      Open3.define_singleton_method(:popen3) { |*_args, **_kwargs| raise Errno::E2BIG }

      begin
        error = assert_raises(Riffer::Error) do
          default_runner.call(["/bin/echo"], env: { "PATH" => "/usr/bin:/bin" }, stdin: "", chdir: Dir.tmpdir,
                                             timeout: 1,)
        end

        expect(error.message).must_match(/could not be spawned.*Argument list too long/)
      ensure
        Open3.define_singleton_method(:popen3, original_popen3)
        $VERBOSE = original_verbose
      end
    end
  end

  describe "Client#stream" do
    let(:default_runner) { Riffer::Providers::ClaudeCode::Client.new }

    it "yields stdout lines as they arrive and returns stderr and status" do
      lines = []

      stderr, status = default_runner.stream(
        ["/bin/sh", "-c", "printf 'one\\ntwo\\n'; echo err >&2"],
        env: { "PATH" => "/usr/bin:/bin" }, stdin: "", chdir: Dir.tmpdir, timeout: 10,
      ) { |line| lines << line }

      expect(lines).must_equal %W[one\n two\n]
      expect(stderr).must_equal "err\n"
      expect(status.success?).must_equal true
    end

    it "kills the child and raises Riffer::TimeoutError on deadline expiry" do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      error = assert_raises(Riffer::TimeoutError) do
        default_runner.stream(["/bin/sleep", "10"], env: { "PATH" => "/usr/bin:/bin" }, stdin: "", chdir: Dir.tmpdir,
                                                    timeout: 0.2,) do |_line|
        end
      end

      expect(error.message).must_match(/timed out after 0.2 seconds/)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).must_be :<, 5
    end

    it "times out when a grandchild inherits the pipes after the child exits within the deadline" do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      argv = ["/bin/sh", "-c", "echo hi; sleep 2 & exit 0"]
      error = assert_raises(Riffer::TimeoutError) do
        default_runner.stream(argv, env: { "PATH" => "/usr/bin:/bin" }, stdin: "", chdir: Dir.tmpdir,
                                    timeout: 0.3,) do |_line|
        end
      end

      expect(error.message).must_match(/timed out after 0\.3 seconds/)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).must_be :<, 1.5
    end

    it "joins the pipe threads before re-raising a block error, so popen3's ensure never closes a live reader's IOs" do
      original_report_on_exception = Thread.report_on_exception
      Thread.report_on_exception = true
      captured_stderr = StringIO.new
      original_stderr = $stderr
      $stderr = captured_stderr

      begin
        assert_raises(RuntimeError) do
          default_runner.stream(
            ["/bin/sh", "-c", "printf 'one\\ntwo\\nthree\\n'; sleep 0.1"],
            env: { "PATH" => "/usr/bin:/bin" }, stdin: "", chdir: Dir.tmpdir, timeout: 10,
          ) { |line| raise "boom" if line == "one\n" }
        end
        sleep 0.2 # lets any leaked reader thread hit popen3's IO-close race, if unfixed
      ensure
        $stderr = original_stderr
        Thread.report_on_exception = original_report_on_exception
      end

      expect(captured_stderr.string).wont_include "IOError"
    end

    it "returns promptly and kills the child when the block breaks out of the stream early" do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      default_runner.stream(
        ["/bin/sh", "-c", "printf 'one\\ntwo\\n'; sleep 8"],
        env: { "PATH" => "/usr/bin:/bin" }, stdin: "", chdir: Dir.tmpdir, timeout: 10,
      ) { |line| break if line == "one\n" }

      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).must_be :<, 5
    end
  end

  describe "multi-turn session resume" do
    it "resumes the recorded session on the second turn, sending only the new user message" do
      two_turn_runner = FakeClaudeCodeRunner.new(stdouts: [fixture("success_text.json"), fixture("success_text.json")])
      multi_turn_provider = build_provider(runner: two_turn_runner)
      first = multi_turn_provider.generate_text(prompt: "hi", model: model)
      messages = [
        { role: "user", content: "hi" },
        { role: "assistant", content: first.content },
        { role: "user", content: "again" },
      ]

      multi_turn_provider.generate_text(messages: messages, model: model)

      second_call = two_turn_runner.calls.fetch(1)

      expect(argv_pairs(second_call[:argv])).must_include ["--resume", "00000000-0000-4000-8000-000000000001"]
      expect(second_call[:stdin]).must_equal "again"
    end

    it "omits the system-prompt and session-id flags on a resumed turn" do
      two_turn_runner = FakeClaudeCodeRunner.new(stdouts: [fixture("success_text.json"), fixture("success_text.json")])
      multi_turn_provider = build_provider(runner: two_turn_runner)
      first = multi_turn_provider.generate_text(prompt: "hi", model: model)
      messages = [
        { role: "user", content: "hi" },
        { role: "assistant", content: first.content },
        { role: "user", content: "again" },
      ]

      multi_turn_provider.generate_text(messages: messages, model: model)

      second_argv = two_turn_runner.calls.fetch(1)[:argv]

      expect(second_argv).wont_include "--append-system-prompt"
      expect(second_argv).wont_include "--system-prompt"
      expect(second_argv).wont_include "--session-id"
    end

    it "does not claim the session for a stream_text enumerator that is never iterated" do
      two_turn_runner = FakeClaudeCodeRunner.new(stdouts: [fixture("success_text.json"), fixture("success_text.json")])
      multi_turn_provider = build_provider(runner: two_turn_runner)
      first = multi_turn_provider.generate_text(prompt: "hi", model: model)
      messages = [
        { role: "user", content: "hi" },
        { role: "assistant", content: first.content },
        { role: "user", content: "again" },
      ]

      _unconsumed_stream = multi_turn_provider.stream_text(messages: messages, model: model)
      multi_turn_provider.generate_text(messages: messages, model: model)

      second_call = two_turn_runner.calls.fetch(1)

      expect(argv_pairs(second_call[:argv])).must_include ["--resume", "00000000-0000-4000-8000-000000000001"]
    end

    it "raises a fingerprint-miss error resuming through a different provider instance" do
      first_provider = build_provider(runner: FakeClaudeCodeRunner.new(stdout: fixture("success_text.json")))
      first = first_provider.generate_text(prompt: "hi", model: model)
      other_provider = build_provider(runner: runner)
      messages = [
        { role: "user", content: "hi" },
        { role: "assistant", content: first.content },
        { role: "user", content: "again" },
      ]

      error = assert_raises(Riffer::ArgumentError) { other_provider.generate_text(messages: messages, model: model) }

      expect(error.message).must_match(/cannot replay fabricated history/)
    end

    it "raises on system-prompt drift between turns of a resumed session" do
      two_turn_runner = FakeClaudeCodeRunner.new(stdouts: [fixture("success_text.json"), fixture("success_text.json")])
      multi_turn_provider = build_provider(runner: two_turn_runner)
      first = multi_turn_provider.generate_text(prompt: "hi", system: "Be terse", model: model)
      drifted_messages = [
        { role: "system", content: "Be verbose" },
        { role: "user", content: "hi" },
        { role: "assistant", content: first.content },
        { role: "user", content: "again" },
      ]

      error = assert_raises(Riffer::ArgumentError) { multi_turn_provider.generate_text(messages: drifted_messages, model: model) }

      expect(error.message).must_match(/system-prompt drift/)
    end

    it "keeps session_persistence: false single-turn, raising on multi-turn history" do
      stateless_provider = build_provider(runner: runner, session_persistence: false)
      first = stateless_provider.generate_text(prompt: "hi", model: model)
      messages = [
        { role: "user", content: "hi" },
        { role: "assistant", content: first.content },
        { role: "user", content: "again" },
      ]

      error = assert_raises(Riffer::ArgumentError) { stateless_provider.generate_text(messages: messages, model: model) }

      expect(error.message).must_match(/session_persistence.*assistant/m)
    end

    it "resumes session-a as its own CLI invocation, isolated from a concurrent session-b" do
      tracking_runner = TrackingClaudeCodeRunner.new(session_id_for: lambda { |stdin|
        stdin.include?("A") ? "session-a" : "session-b"
      })
      concurrent_provider = build_provider(runner: tracking_runner)
      threads = start_concurrent_conversations(concurrent_provider)
      threads.each(&:join)

      a_resume = tracking_runner.calls.find do |call|
        call[:session_id] == "session-a" && call[:argv].include?("--resume")
      end

      expect(argv_pairs(a_resume[:argv])).must_include ["--resume", "session-a"]
      expect(a_resume[:stdin]).must_equal "again A"
    end

    it "resumes session-b as its own CLI invocation, isolated from a concurrent session-a" do
      tracking_runner = TrackingClaudeCodeRunner.new(session_id_for: lambda { |stdin|
        stdin.include?("A") ? "session-a" : "session-b"
      })
      concurrent_provider = build_provider(runner: tracking_runner)
      threads = start_concurrent_conversations(concurrent_provider)
      threads.each(&:join)

      b_resume = tracking_runner.calls.find do |call|
        call[:session_id] == "session-b" && call[:argv].include?("--resume")
      end

      expect(argv_pairs(b_resume[:argv])).must_include ["--resume", "session-b"]
      expect(b_resume[:stdin]).must_equal "again B"
    end

    it "lets only one of two concurrent resumes from the same prefix succeed, the other raising a fingerprint-miss" do
      two_turn_runner = FakeClaudeCodeRunner.new(stdouts: [fixture("success_text.json"), fixture("success_text.json")])
      shared_provider = build_provider(runner: two_turn_runner)
      first = shared_provider.generate_text(prompt: "hi", model: model)
      messages = [
        { role: "user", content: "hi" },
        { role: "assistant", content: first.content },
        { role: "user", content: "again" },
      ]

      outcomes = Array.new(2) do
        Thread.new do
          shared_provider.generate_text(messages: messages, model: model)
          :ok
        rescue Riffer::ArgumentError
          :fingerprint_miss
        end
      end.map(&:value)

      expect(outcomes.sort).must_equal %i[fingerprint_miss ok]
      expect(two_turn_runner.calls.length).must_equal 2
    end

    it "deletes the consumed prefix entry on resume, so branching from it again raises a fingerprint-miss" do
      runner_with_two_resumes = FakeClaudeCodeRunner.new(stdouts: [fixture("success_text.json"),
                                                                   fixture("success_text.json"),])
      provider_with_two_resumes = build_provider(runner: runner_with_two_resumes)
      first = provider_with_two_resumes.generate_text(prompt: "hi", model: model)
      messages = [
        { role: "user", content: "hi" },
        { role: "assistant", content: first.content },
        { role: "user", content: "again" },
      ]
      provider_with_two_resumes.generate_text(messages: messages, model: model)

      error = assert_raises(Riffer::ArgumentError) { provider_with_two_resumes.generate_text(messages: messages, model: model) }

      expect(error.message).must_match(/cannot replay fabricated history/)
    end

    it "keeps the prefix entry on a failed resume, so a retry from the same prefix can still resume" do
      fail_then_succeed_runner = FakeClaudeCodeRunner.new(
        stdouts: [fixture("success_text.json"), fixture("error_api.json"), fixture("success_text.json")],
      )
      retry_provider = build_provider(runner: fail_then_succeed_runner)
      first = retry_provider.generate_text(prompt: "hi", model: model)
      messages = [
        { role: "user", content: "hi" },
        { role: "assistant", content: first.content },
        { role: "user", content: "again" },
      ]
      assert_raises(Riffer::Error) { retry_provider.generate_text(messages: messages, model: model) }

      retry_provider.generate_text(messages: messages, model: model)
    end

    # Drives two independent conversations ("A" and "B") concurrently through
    # one provider instance, each a first turn followed immediately by a
    # resume, so the two examples above can each inspect one side's resume.
    def start_concurrent_conversations(concurrent_provider)
      [0, 1].map do |i|
        Thread.new do
          label = i.zero? ? "A" : "B"
          first = concurrent_provider.generate_text(prompt: "hello #{label}", model: model)
          messages = [
            { role: "user", content: "hello #{label}" },
            { role: "assistant", content: first.content },
            { role: "user", content: "again #{label}" },
          ]
          concurrent_provider.generate_text(messages: messages, model: model)
        end
      end
    end
  end
end
