# frozen_string_literal: true
# rbs_inline: enabled

require "digest"
require "json"
require "securerandom"
require "tmpdir"

# Shells out to the installed +claude+ binary in headless mode
# (<tt>claude -p</tt>), running under the operator's existing Claude Code
# login. Multi-turn conversations resume a CLI session (<tt>--resume</tt>)
# when +session_persistence+ is enabled (the default). The system prompt
# travels on argv (<tt>--append-system-prompt</tt>/<tt>--system-prompt</tt>),
# so it is visible to +ps+ and subject to the OS argv size limit (ARG_MAX).
class Riffer::Providers::ClaudeCode < Riffer::Providers::Base
  # @rbs @resolved_binary: String?
  # @rbs @sessions: Hash[String, Hash[Symbol, untyped]]
  # @rbs @sessions_mutex: Mutex
  # @rbs self.@private_cwd: String?

  PRIVATE_CWD_MUTEX = Mutex.new #: Mutex

  # Referencing FINISH_REASONS does not require the anthropic gem: anthropic.rb
  # only calls +depends_on+ from #initialize.
  FINISH_REASONS = Riffer::Providers::Anthropic::FINISH_REASONS #: Hash[String, Symbol]

  DEFAULT_MODEL_SENTINEL = "default" #: String

  # These vars outrank the CLI's OAuth login, so :subscription mode scrubs
  # them from the child env to keep a stray key from silently getting billed.
  DEFAULT_SCRUB_ENV = %w[
    ANTHROPIC_API_KEY
    ANTHROPIC_AUTH_TOKEN
    ANTHROPIC_BASE_URL
    ANTHROPIC_BEDROCK_BASE_URL
    ANTHROPIC_BEDROCK_MANTLE_BASE_URL
    ANTHROPIC_FOUNDRY_API_KEY
    ANTHROPIC_FOUNDRY_AUTH_TOKEN
    ANTHROPIC_FOUNDRY_BASE_URL
    ANTHROPIC_FOUNDRY_RESOURCE
    ANTHROPIC_VERTEX_BASE_URL
    ANTHROPIC_VERTEX_PROJECT_ID
    AWS_BEARER_TOKEN_BEDROCK
    CLAUDE_CODE_USE_ANTHROPIC_AWS
    CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD
    CLAUDE_CODE_USE_BEDROCK
    CLAUDE_CODE_USE_FOUNDRY
    CLAUDE_CODE_USE_GATEWAY
    CLAUDE_CODE_USE_MANTLE
    CLAUDE_CODE_USE_VERTEX
  ].freeze #: Array[String]

  # Caps the instance-level session map, evicting the oldest entry, so a
  # long-lived provider driving many conversations can't grow it unbounded.
  MAX_SESSIONS = 1000 #: Integer

  AUTH_MODES = %i[subscription api_key].freeze #: Array[Symbol]

  SYSTEM_PROMPT_MODES = %i[append replace].freeze #: Array[Symbol]

  # Validated as defense in depth even though argv never passes through a
  # shell. Admits context-window variants (+sonnet[1m]+), Vertex ids
  # (+claude-sonnet-4-5@20250929+), and Bedrock ids (+anthropic.claude-...-v1:0+).
  MODEL_SEGMENT_FORMAT = /\A[A-Za-z0-9][A-Za-z0-9._:@-]*(?:\[[A-Za-z0-9]+\])?\z/ #: Regexp

  #--
  #: (?String?) -> singleton(Riffer::Skills::Adapter)
  def self.skills_adapter(_model = nil)
    Riffer::Skills::XmlAdapter
  end

  #--
  #: () -> String
  def self.semconv_provider_name
    "claude_code"
  end

  #--
  #: () -> void
  def initialize
    super
    @sessions = {}
    @sessions_mutex = Mutex.new
  end

  # Class-level (not per-instance): the CLI keys session transcripts by cwd
  # in +~/.claude/projects+, and agents build one provider per Agent instance.
  #--
  #: () -> String
  def self.private_cwd
    PRIVATE_CWD_MUTEX.synchronize { @private_cwd ||= Dir.mktmpdir("riffer-claude-code-") }
  end

  private

  #--
  #: () -> Riffer::Config::ClaudeCode
  def config
    Riffer.config.claude_code
  end

  #--
  #: () -> untyped
  def global_client
    config.client
  end

  #--
  #: () -> untyped
  def build_client
    Riffer::Providers::ClaudeCode::Client.new
  end

  #--
  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    validate_config!

    tools = options[:tools]
    if tools && !tools.empty?
      raise Riffer::ArgumentError, "claude_code does not support riffer tools; use an API provider or remove tools"
    end

    {
      partitioned: partition_messages(messages), resolved_model: resolve_model!(model),
      structured_output: options[:structured_output], env: child_env, timeout: call_timeout,
    }
  end

  #--
  #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def execute_generate(params)
    with_session_claim(params) do |request|
      stdout, stderr, status = client.call(
        request[:argv] + ["--output-format", "json"],
        env: params[:env],
        stdin: request[:prompt],
        chdir: request[:cwd],
        timeout: params[:timeout],
      )

      envelope = parse_envelope(stdout)
      if envelope.nil?
        raise Riffer::Error,
              "claude CLI produced unparseable output (exit #{status.exitstatus}): #{diagnostic(stdout, stderr)}"
      end
      raise Riffer::Error, failure_message(envelope, stderr, status) if !status.success? || envelope[:is_error]

      record_session(request, envelope)
      envelope
    end
  end

  # TextDone comes only from the terminal +result+ line, so the reconstructed
  # content always matches what the envelope's own fingerprint covers.
  #--
  #: (Hash[Symbol, untyped], Riffer::Providers::_EventSink) -> void
  def execute_stream(params, yielder)
    with_session_claim(params) do |request|
      state = { block_types: {}, reasoning: {}, result: nil } #: Hash[Symbol, untyped]

      stderr, status = client.stream(
        request[:argv] + ["--output-format", "stream-json", "--include-partial-messages", "--verbose"],
        env: params[:env],
        stdin: request[:prompt],
        chdir: request[:cwd],
        timeout: params[:timeout],
      ) do |line|
        handle_stream_line(line, state: state, yielder: yielder)
      end

      envelope = state[:result]
      if envelope.nil?
        raise Riffer::IncompleteStreamError, "claude CLI stream ended without a result event: #{diagnostic('', stderr)}"
      end
      raise Riffer::Error, failure_message(envelope, stderr, status) if !status.success? || envelope[:is_error]

      yielder << Riffer::StreamEvents::TextDone.new(extract_content(envelope))
      yield_finish_reason(yielder, extract_finish_reason(envelope))
      token_usage = extract_token_usage(envelope)
      yielder << Riffer::StreamEvents::TokenUsageDone.new(token_usage: token_usage) if token_usage
      record_session(request, envelope)
    end
  end

  # Ignores +assistant+ lines: they're complete blocks, redundant with the deltas.
  #--
  #: (String, state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_stream_line(line, state:, yielder:)
    parsed = begin
      JSON.parse(line, symbolize_names: true)
    rescue JSON::ParserError => e
      raise Riffer::Error, "claude CLI stream produced an unparseable line (#{e.message}): #{line.strip[0, 200]}"
    end

    case parsed[:type].to_s
    when "stream_event"
      handle_stream_event(parsed[:event], state: state, yielder: yielder)
    when "result"
      state[:result] = parsed
    end
  end

  #--
  #: (Hash[Symbol, untyped], state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_stream_event(event, state:, yielder:)
    case event[:type].to_s
    when "content_block_start"
      handle_content_block_start(event, state: state)
    when "content_block_delta"
      handle_content_block_delta(event, state: state, yielder: yielder)
    when "content_block_stop"
      handle_content_block_stop(event, state: state, yielder: yielder)
    end
  end

  # The CLI's internal agent loop restarts block indexes at 0 per internal
  # message, so the reasoning buffer must reset here or bleed across blocks.
  #--
  #: (Hash[Symbol, untyped], state: Hash[Symbol, untyped]) -> void
  def handle_content_block_start(event, state:)
    index = event[:index]
    block_type = event.dig(:content_block, :type).to_s
    state[:block_types][index] = block_type
    state[:reasoning][index] = +"" if block_type == "thinking"
  end

  #--
  #: (Hash[Symbol, untyped], state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_content_block_delta(event, state:, yielder:)
    delta = event[:delta] || {}

    case delta[:type].to_s
    when "text_delta"
      yielder << Riffer::StreamEvents::TextDelta.new(delta[:text].to_s)
    when "thinking_delta"
      index = event[:index]
      thinking = delta[:thinking].to_s
      # +""+ seeds an unfrozen buffer so << stays legal under frozen_string_literal.
      (state[:reasoning][index] ||= +"") << thinking
      yielder << Riffer::StreamEvents::ReasoningDelta.new(thinking)
    end
  end

  #--
  #: (Hash[Symbol, untyped], state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_content_block_stop(event, state:, yielder:)
    index = event[:index]
    case state[:block_types][index]
    when "thinking"
      yield_reasoning_done(yielder, state[:reasoning][index] || "")
    end
  end

  # TokenUsage#input includes the cache buckets (Anthropic convention).
  # +total_cost_usd+ is API-equivalent dollars, not billed dollars under
  # subscription auth; falls back to apply_pricing when absent.
  #--
  #: (untyped) -> Riffer::Providers::TokenUsage?
  def extract_token_usage(response)
    usage = response[:usage] || {}
    cache_write = usage[:cache_creation_input_tokens]
    cache_read = usage[:cache_read_input_tokens]
    cost = response[:total_cost_usd]

    token_usage = Riffer::Providers::TokenUsage.new(
      input_tokens: (usage[:input_tokens] || 0) + (cache_write || 0) + (cache_read || 0),
      output_tokens: usage[:output_tokens] || 0,
      cache_write_tokens: cache_write,
      cache_read_tokens: cache_read,
      cost: cost,
    )
    cost.nil? ? apply_pricing(token_usage) : token_usage
  end

  # A +--json-schema+ call ends with stop_reason "tool_use" (the CLI's own
  # structured-output tool, not a riffer tool call), so it maps to :stop.
  #--
  #: (untyped) -> Riffer::Providers::FinishReason?
  def extract_finish_reason(response)
    raw = response[:stop_reason].to_s
    return nil if raw.empty?

    reason = FINISH_REASONS.fetch(raw, :other)
    reason = :stop if reason == :tool_calls && response[:structured_output]
    Riffer::Providers::FinishReason.new(reason: reason, raw: raw)
  end

  #--
  #: (untyped) -> String
  def extract_content(response)
    response[:result].to_s
  end

  # +claude -p+ runs its own internal agent loop; riffer-level tool calls never surface.
  #--
  #: (untyped) -> Array[Riffer::Messages::Assistant::ToolCall]
  def extract_tool_calls(_response)
    []
  end

  # History can only be replayed via CLI session resume (+plan_turn+), never
  # fabricated back to the CLI, so non-User/Assistant roles and tool calls raise.
  #--
  #: (Array[Riffer::Messages::Base]) -> Hash[Symbol, untyped]
  def partition_messages(messages)
    system_parts = [] #: Array[String]
    conversation = [] #: Array[Riffer::Messages::Base]

    messages.each do |message|
      case message
      when Riffer::Messages::System
        system_parts << message.content
      when Riffer::Messages::User
        raise Riffer::ArgumentError, "claude_code does not support file attachments" unless message.files.empty?

        conversation << message
      when Riffer::Messages::Assistant
        unless session_persistence?
          raise Riffer::ArgumentError,
                "claude_code requires session_persistence to accept assistant messages (multi-turn history)"
        end
        if message.has_tool_calls?
          raise Riffer::ArgumentError, "claude_code cannot resume history containing tool calls"
        end

        conversation << message
      else
        raise Riffer::ArgumentError, "claude_code does not support #{message.role} messages"
      end
    end

    unless conversation.last.is_a?(Riffer::Messages::User)
      raise Riffer::ArgumentError, "claude_code requires the conversation to end in a user message"
    end

    { system: system_parts.empty? ? nil : system_parts.join("\n\n"), conversation: conversation }
  end

  # Resuming atomically claims the prior turn's session entry, so two calls
  # branching from the same history can't both resume it — the loser raises.
  #--
  #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def plan_turn(partitioned)
    conversation = partitioned[:conversation] #: Array[Riffer::Messages::Base]
    system_digest = digest(partitioned[:system].to_s)
    fingerprint_pairs = pairs_for(conversation)

    if conversation.size == 1
      return {
        mode: :fresh, session_id: (SecureRandom.uuid if session_persistence?), cwd: cwd,
        prompt: conversation.first.content, system_digest: system_digest, fingerprint_pairs: fingerprint_pairs,
      }
    end

    prior_key = fingerprint(pairs_for(conversation[0...-1] || []))
    session = @sessions_mutex.synchronize { @sessions.delete(prior_key) }
    unless session
      raise Riffer::ArgumentError,
            "claude_code cannot replay fabricated history: this provider only resumes conversations it recorded itself"
    end
    if session[:system_digest] != system_digest
      restore_prior_session(prior_key, session)
      raise Riffer::ArgumentError,
            "claude_code detected system-prompt drift: system content must stay stable across a resumed conversation"
    end

    {
      mode: :resume, session_id: session[:session_id], cwd: session[:cwd],
      prompt: conversation.last.content, system_digest: system_digest, fingerprint_pairs: fingerprint_pairs,
      prior_key: prior_key, prior_session: session,
    }
  end

  # Claims the session at execution time, not in +build_request_params+, so
  # an unconsumed +stream_text+ enumerator never claims a session it doesn't
  # spend. Puts a claimed-but-unspent entry back so a same-prefix retry can resume it.
  #--
  #: (Hash[Symbol, untyped]) { (Hash[Symbol, untyped]) -> untyped } -> untyped
  def with_session_claim(params, &)
    turn = plan_turn(params[:partitioned])
    argv = build_argv(turn, params[:partitioned], params[:resolved_model], params[:structured_output])
    request = turn.merge(argv: argv)

    succeeded = false #: bool
    begin
      result = yield(request)
      succeeded = true
      result
    ensure
      restore_prior_session(turn[:prior_key], turn[:prior_session]) unless succeeded
    end
  end

  #--
  #: (Hash[Symbol, untyped], Hash[Symbol, untyped], String, untyped) -> Array[String]
  def build_argv(turn, partitioned, resolved_model, structured_output)
    argv = [
      resolved_binary, "-p",
      "--allowedTools", allowed_tools.join(","),
      "--tools", allowed_tool_names.join(","),
      "--setting-sources", setting_sources,
    ] #: Array[String]
    argv.push("--model", resolved_model) unless resolved_model == DEFAULT_MODEL_SENTINEL
    argv.push("--json-schema", JSON.generate(structured_output.json_schema(strict: true))) if structured_output

    case turn[:mode]
    when :resume
      argv.push("--resume", turn[:session_id])
    else
      argv.push("--no-session-persistence") unless session_persistence?
      argv.push("--session-id", turn[:session_id]) if turn[:session_id]
      argv.push(system_prompt_flag, partitioned[:system]) if partitioned[:system]
    end

    argv
  end

  #--
  #: (String?, Hash[Symbol, untyped]?) -> void
  def restore_prior_session(prior_key, prior_session)
    return unless prior_key && prior_session

    @sessions_mutex.synchronize { @sessions[prior_key] ||= prior_session }
  end

  # Not called on failure, so a retry of a failed turn can still resume via
  # the claimed prefix entry that +with_session_claim+ restores.
  #--
  #: (Hash[Symbol, untyped], Hash[Symbol, untyped]) -> void
  def record_session(params, envelope)
    return unless session_persistence?

    pairs = params[:fingerprint_pairs] + [["assistant", extract_content(envelope)]]
    key = fingerprint(pairs)
    @sessions_mutex.synchronize do
      @sessions[key] = { session_id: envelope[:session_id], cwd: params[:cwd], system_digest: params[:system_digest] }
      @sessions.delete(@sessions.keys.first) while @sessions.size > MAX_SESSIONS
    end
  end

  #--
  #: (Array[Riffer::Messages::Base]) -> Array[[String, String]]
  def pairs_for(conversation)
    conversation.map { |message| [message.role.to_s, message.content] }
  end

  #--
  #: (Array[[String, String]]) -> String
  def fingerprint(pairs)
    digest(JSON.generate(pairs))
  end

  #--
  #: (String) -> String
  def digest(text)
    Digest::SHA256.hexdigest(text)
  end

  #--
  #: (String?) -> String
  def resolve_model!(model)
    resolved = model || default_model
    unless resolved
      raise Riffer::ArgumentError,
            "claude_code requires an explicit model; pass \"claude_code/<id>\", or " \
            "\"claude_code/#{DEFAULT_MODEL_SENTINEL}\" to opt into the CLI's configured default"
    end
    unless MODEL_SEGMENT_FORMAT.match?(resolved)
      raise Riffer::ArgumentError, "invalid claude_code model segment #{resolved.inspect}"
    end

    resolved
  end

  #--
  #: () -> String
  def system_prompt_flag
    system_prompt_mode == :replace ? "--system-prompt" : "--append-system-prompt"
  end

  # The runner treats this hash as the complete child environment, so a
  # deleted key is genuinely absent, not shadowed by the parent's.
  #--
  #: () -> Hash[String, String]
  def child_env
    env = ENV.to_h
    scrub_env.each { |name| env.delete(name) } if auth_mode == :subscription
    env
  end

  #--
  #: (String) -> Hash[Symbol, untyped]?
  def parse_envelope(stdout)
    parsed = JSON.parse(stdout, symbolize_names: true)
    parsed.is_a?(Hash) ? parsed : nil
  rescue JSON::ParserError
    nil
  end

  # On failure the CLI keeps <tt>subtype: "success"</tt>; +terminal_reason+
  # and +api_error_status+ carry the real detail, not +subtype+.
  #--
  #: (Hash[Symbol, untyped], String, untyped) -> String
  def failure_message(envelope, stderr, status)
    detail = envelope[:result].to_s.strip
    detail = stderr.to_s.strip if detail.empty?
    context = ["exit #{status.exitstatus}"] #: Array[String]
    context << envelope[:terminal_reason].to_s if envelope[:terminal_reason]
    context << "api_error_status=#{envelope[:api_error_status]}" if envelope[:api_error_status]
    "claude CLI call failed (#{context.join(', ')}): #{detail}"
  end

  #--
  #: (String, String) -> String
  def diagnostic(stdout, stderr)
    text = stderr.to_s.strip
    text = stdout.to_s.strip if text.empty?
    text[0, 500].to_s
  end

  #--
  #: () -> void
  def validate_config!
    unless AUTH_MODES.include?(auth_mode)
      raise Riffer::ArgumentError, "claude_code auth must be one of #{AUTH_MODES.inspect}, got #{auth_mode.inspect}"
    end
    return if SYSTEM_PROMPT_MODES.include?(system_prompt_mode)

    raise Riffer::ArgumentError,
          "claude_code system_prompt_mode must be one of #{SYSTEM_PROMPT_MODES.inspect}, got " \
          "#{system_prompt_mode.inspect}"
  end

  #--
  #: () -> Symbol
  def auth_mode
    config.auth || :subscription
  end

  #--
  #: () -> String?
  def default_model
    config.default_model
  end

  # Headless mode (+-p+) skips the workspace-trust check, so a shared temp
  # dir would let a planted +.claude/settings.json+ run hooks under this
  # process — the default cwd is process-private instead.
  #--
  #: () -> String
  def cwd
    config.cwd || self.class.private_cwd
  end

  #--
  #: () -> Numeric
  def call_timeout
    config.timeout || 120
  end

  #--
  #: () -> Array[String]
  def scrub_env
    config.scrub_env || DEFAULT_SCRUB_ENV
  end

  #--
  #: () -> String
  def setting_sources
    config.setting_sources || "project"
  end

  #--
  #: () -> Symbol
  def system_prompt_mode
    config.system_prompt_mode || :append
  end

  #--
  #: () -> bool
  def session_persistence?
    value = config.session_persistence
    value.nil? || value
  end

  #--
  #: () -> Array[String]
  def allowed_tools
    config.allowed_tools || []
  end

  # +--tools+ only accepts built-in tool names, not permission rules — a
  # rule such as +Bash(git *)+ makes the CLI silently drop the tool.
  #--
  #: () -> Array[String]
  def allowed_tool_names
    allowed_tools.filter_map { |rule| rule[/\A[^(]+/] }.uniq
  end

  #--
  #: () -> String
  def resolved_binary
    @resolved_binary ||= resolve_binary!(config.binary || "claude")
  end

  #--
  #: (String) -> String
  def resolve_binary!(binary)
    resolved = binary.include?(File::SEPARATOR) ? File.expand_path(binary) : find_on_path(binary)
    unless resolved && File.file?(resolved) && File.executable?(resolved)
      raise Riffer::Error,
            "claude CLI binary not found or not executable: #{binary.inspect}. Install Claude Code, or set " \
            "config.claude_code.binary to an absolute path."
    end

    resolved
  end

  #--
  #: (String) -> String?
  def find_on_path(binary)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, binary) }.
      find { |candidate| File.file?(candidate) && File.executable?(candidate) }
  end
end
