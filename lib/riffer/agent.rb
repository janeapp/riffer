# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Riffer::Agent is the base class for all agents in the Riffer framework.
#
# Provides orchestration for LLM calls, tool use, and message management.
# Subclass this to create your own agents.
#
# See Riffer::Messages and Riffer::Providers.
#
#   class MyAgent < Riffer::Agent
#     model 'openai/gpt-4o'
#     instructions 'You are a helpful assistant.'
#   end
#
#   agent = MyAgent.new
#   agent.generate('Hello!')
#
class Riffer::Agent
  # @rbs self.@config: Riffer::Agent::Config?

  include Riffer::Messages::Converter
  extend Riffer::Helpers::ClassNameConverter

  INTERRUPT_MAX_STEPS = :max_steps #: Symbol

  # Returns the per-class Riffer::Agent::Config value object holding every
  # DSL setting. Lazily initialized on first read; each subclass has its own.
  #
  #--
  #: () -> Riffer::Agent::Config
  def self.config
    @config ||= Riffer::Agent::Config.new
  end

  # Gets or sets the agent identifier.
  #
  #--
  #: (?String?) -> String
  def self.identifier(value = nil)
    value.nil? ? (config.identifier || class_name_to_path(name)) : (config.identifier = value)
  end

  # Gets or sets the model string (e.g., "openai/gpt-4o") or Proc.
  #
  #--
  #: (?(String | Proc)?) -> (String | Proc)?
  def self.model(value = nil)
    value.nil? ? config.model : (config.model = value)
  end

  # Gets or sets the agent instructions.
  #
  # Accepts a static string or a Proc for dynamic instructions.
  # When a Proc is given, it is called at generate time and receives
  # the +context+ hash (which may be +nil+).
  #
  #   instructions "You are a helpful assistant."
  #
  #   instructions -> (context) {
  #     "You are assisting #{context[:name]}"
  #   }
  #
  #--
  #: (?(String | Proc)?) -> (String | Proc)?
  def self.instructions(value = nil)
    value.nil? ? config.instructions : (config.instructions = value)
  end

  # Gets or sets provider options passed to the provider client.
  #
  #--
  #: (?Hash[Symbol, untyped]?) -> Hash[Symbol, untyped]
  def self.provider_options(options = nil)
    options.nil? ? config.provider_options : (config.provider_options = options)
  end

  # Gets or sets model options passed to generate_text/stream_text.
  #
  #--
  #: (?Hash[Symbol, untyped]?) -> Hash[Symbol, untyped]
  def self.model_options(options = nil)
    options.nil? ? config.model_options : (config.model_options = options)
  end

  # Gets or sets the structured output schema for this agent.
  #
  # Accepts a Riffer::Params instance or a block evaluated against a new Params.
  #
  #--
  #: (?Riffer::Params?) ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> Riffer::Params?
  def self.structured_output(params = nil, &block)
    if block
      params = Riffer::Params.new
      params.instance_eval(&block)
    end
    config.structured_output = params if params
    config.structured_output
  end

  # Gets or sets the maximum number of LLM call steps in the tool-use loop.
  #
  # Defaults to Riffer::Agent::Config::DEFAULT_MAX_STEPS (16). Set to
  # +Float::INFINITY+ for unlimited steps.
  #
  #--
  #: (?Numeric?) -> Numeric
  def self.max_steps(value = nil)
    value.nil? ? config.max_steps : (config.max_steps = value)
  end

  # Gets or sets the tools used by this agent.
  #
  #--
  #: (?(Array[singleton(Riffer::Tool)] | Proc)?) -> (Array[singleton(Riffer::Tool)] | Proc)?
  def self.uses_tools(value = nil)
    value.nil? ? config.tools_config : (config.tools_config = value)
  end

  # Opts this agent into tools from all MCP registrations that share any of
  # the given tag(s).
  #
  # +tag+ - a String or Symbol; matched against registration manifest tags.
  #
  #: (String | Symbol) -> void
  def self.use_mcp(tag)
    config.add_mcp(tag)
  end

  # Returns the accumulated +use_mcp+ configurations for this agent class.
  #
  #: () -> Array[Hash[Symbol, untyped]]
  def self.mcp_configs
    config.mcp_configs
  end

  # Gets or sets the tool runtime for this agent.
  #
  # Accepts a Riffer::Tools::Runtime subclass, a Riffer::Tools::Runtime instance,
  # or a Proc. Defaults to <tt>Riffer.config.tool_runtime</tt> when unset.
  #
  #--
  #: (?(singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)
  def self.tool_runtime(value = nil)
    value.nil? ? config.tool_runtime : (config.tool_runtime = value)
  end

  # Configures skills for this agent via a block DSL.
  #
  # Returns the current Riffer::Skills::Config when called without a block.
  #
  #   skills do
  #     backend Riffer::Skills::FilesystemBackend.new(".skills")
  #     adapter Riffer::Skills::XmlAdapter
  #     activate ["code-review"]
  #   end
  #
  #--
  #: () ?{ (Riffer::Skills::Config) [self: Riffer::Skills::Config] -> void } -> Riffer::Skills::Config?
  def self.skills(&block)
    if block
      skills_config = Riffer::Skills::Config.new
      skills_config.instance_eval(&block)
      config.skills_config = skills_config
    end
    config.skills_config
  end

  # Finds an agent class by identifier.
  #
  #--
  #: (String) -> singleton(Riffer::Agent)?
  def self.find(identifier)
    all.find { |agent_class| agent_class.identifier == identifier.to_s }
  end

  # Returns all agent subclasses.
  #
  #--
  #: () -> Array[singleton(Riffer::Agent)]
  def self.all
    subclasses #: Array[singleton(Riffer::Agent)]
  end

  # Generates a response using a new agent instance.
  #
  # +context:+ is threaded into +new+; +prompt+ and +files:+ are forwarded
  # to +#generate+.
  #
  #--
  #: (?String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?, ?context: Hash[Symbol, untyped]?) -> Riffer::Agent::Response
  def self.generate(prompt = nil, files: nil, context: nil)
    new(context: context).generate(prompt, files: files)
  end

  # Streams a response using a new agent instance.
  #
  # +context:+ is threaded into +new+; +prompt+ and +files:+ are forwarded
  # to +#stream+.
  #
  #--
  #: (?String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?, ?context: Hash[Symbol, untyped]?) -> Enumerator[Riffer::StreamEvents::Base, void]
  def self.stream(prompt = nil, files: nil, context: nil)
    new(context: context).stream(prompt, files: files)
  end

  # Registers a guardrail for input, output, or both phases.
  #
  # [phase] :before, :after, or :around.
  # [with] the guardrail class (must be subclass of Riffer::Guardrail).
  # [options] additional options passed to the guardrail.
  #
  # Raises Riffer::ArgumentError if phase is invalid or guardrail is not a Guardrail class.
  #--
  #: (Symbol, with: singleton(Riffer::Guardrail), **untyped) -> void
  def self.guardrail(phase, with:, **options)
    config.add_guardrail(phase, klass: with, options: options)
  end

  # Returns the registered guardrail configs for a given phase.
  #
  # [phase] :before or :after.
  #
  #--
  #: (Symbol) -> Array[Hash[Symbol, untyped]]
  def self.guardrails_for(phase)
    config.guardrails_for(phase)
  end

  # The conversation handle. See Riffer::Agent::Session.
  attr_reader :session #: Riffer::Agent::Session

  # The per-instance Riffer::Agent::Config. Either the class-level default or
  # an explicit Config passed to +Agent.new(config:)+.
  attr_reader :config #: Riffer::Agent::Config

  # The system message built from the configured +instructions+, or +nil+
  # when no instructions are configured. Built once at +Agent.new+ using the
  # constructor +context:+ and cached. Useful for persistence flows.
  attr_reader :instruction_message #: Riffer::Messages::System?

  # The system message describing the configured skills catalog, or +nil+
  # when skills are unconfigured or the catalog is empty. Built once at
  # +Agent.new+ and cached.
  attr_reader :skills_message #: Riffer::Messages::System?

  # The mutable runtime context, a +Riffer::Agent::Context+ value object
  # threaded into every Proc-based DSL setting, guardrail, tool runtime,
  # and skills resolution, and shared with every +Riffer::Agent::Run+
  # this agent executes. Exposes:
  #
  # - +context.skills+ — the resolved +Riffer::Skills::Context+ (when
  #   skills are configured), set at +Agent.new+ time.
  # - +context.token_usage+ — the cumulative +Riffer::Providers::TokenUsage+,
  #   updated by each Run as the loop progresses.
  # - +context[:key]+ / <tt>context.dig(:key)</tt> — Hash-style reads for
  #   caller-provided keys (e.g. <tt>context[:agent]</tt>,
  #   <tt>context[:tenant]</tt>). +:skills+ and +:token_usage+ are
  #   reserved and cannot be passed by the caller.
  attr_reader :context #: Riffer::Agent::Context

  # The resolved model name (the part after "provider/"), used as the model
  # argument on every LLM call. Resolved eagerly at +Agent.new+.
  attr_reader :model_name #: String

  # The provider client. Built eagerly at +Agent.new+ from the configured
  # provider class and +Config#provider_options+, then handed to every
  # +Riffer::Agent::Run+ this agent executes. Public so tests can pre-queue
  # responses on +Riffer::Providers::Mock+ before calling +#generate+.
  attr_reader :provider #: Riffer::Providers::Base

  # The +Riffer::Agent::StructuredOutput+ wrapping the configured schema, or +nil+
  # when structured output is not configured. Resolved eagerly at +Agent.new+.
  attr_reader :structured_output #: Riffer::Agent::StructuredOutput?

  # The tool classes the LLM sees on every call this agent makes. Resolved
  # eagerly at +Agent.new+ (Proc-form +uses_tools+ is called against
  # +context+ once; MCP tools and the skill_activate tool are merged in).
  attr_reader :tools #: Array[singleton(Riffer::Tool)]

  # The tool runtime instance used to execute tool calls. Resolved eagerly
  # at +Agent.new+ (Proc-form +tool_runtime+ is called against +context+ once).
  attr_reader :tool_runtime #: Riffer::Tools::Runtime

  # Initializes a new agent.
  #
  # When +session:+ is omitted, a fresh +Riffer::Agent::Session+ is built and seeded
  # with the system instruction message and skills catalog (when configured),
  # using +context:+. When +session:+ is provided, the agent uses it as-is —
  # the caller is responsible for the session's contents (typical use case:
  # cross-process resume from persisted history). With
  # +Riffer.config.experimental_history_healing+ on, a provided session is
  # healed at construction time so the +tool_use+ ↔ +tool_result+ invariant
  # holds before the next inference call.
  #
  # +context:+ flows through Proc-based instructions, model, skills resolution,
  # tool resolution, guardrails, and tool runtime. It is fixed for the
  # lifetime of the agent.
  #
  # Raises Riffer::ArgumentError if the configured model string is invalid
  # (must be "provider/model" format).
  #
  #--
  #: (?session: Riffer::Agent::Session?, ?context: Hash[Symbol, untyped]?, ?config: Riffer::Agent::Config?) -> void
  def initialize(session: nil, context: nil, config: nil)
    @config = config || self.class.config
    @context = Riffer::Agent::Context.new(context || {})

    provider_class, @model_name = resolve_provider_and_model
    @provider = provider_class.new(**@config.provider_options)

    @context.skills = resolve_skills(provider_class)

    @structured_output = resolve_structured_output
    @tools = resolve_tools
    @tool_runtime = resolve_tool_runtime

    @instruction_message = build_instruction_message
    @skills_message = build_skills_message

    @session = session || Riffer::Agent::Session.new(messages: [@instruction_message, @skills_message].compact)
    @session.set(Riffer::Agent::Session::Repair.prune_orphans(@session.messages))
  end

  # Generates a response from the agent.
  #
  # Runs the inference loop via +Riffer::Agent::Run.generate+. When +prompt+
  # is given, a new +Riffer::Messages::User+ is appended to the session
  # (silently — +on_message+ does not fire for user inputs) and then the
  # loop runs. When +prompt+ is omitted, the loop runs against the current
  # session — useful for resuming a persisted conversation whose last turn
  # is already a user message, or for picking up pending tool calls after
  # an interrupt.
  #
  # +files:+ requires +prompt+. Pass files to attach to the new user message.
  #
  #--
  #: (?String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?) -> Riffer::Agent::Response
  def generate(prompt = nil, files: nil)
    Riffer::Agent::Run.generate(agent: self, prompt: prompt, files: files)
  end

  # Streams a response from the agent.
  #
  # Runs the inference loop via +Riffer::Agent::Run.stream+, returning an
  # +Enumerator+ of +Riffer::StreamEvents+.
  #
  # Raises Riffer::ArgumentError if structured output is configured.
  #
  # See +#generate+ for prompt/files semantics.
  #
  #--
  #: (?String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?) -> Enumerator[Riffer::StreamEvents::Base, void]
  def stream(prompt = nil, files: nil)
    raise Riffer::ArgumentError, "Structured output is not supported with streaming. Use #generate instead." if @structured_output
    Riffer::Agent::Run.stream(agent: self, prompt: prompt, files: files)
  end

  # Interrupts the agent loop.
  #
  # Call from an +on_message+ callback to cleanly interrupt the loop.
  # Equivalent to <tt>throw :riffer_interrupt, reason</tt>.
  #
  # When +Riffer.config.experimental_history_healing+ is enabled, riffer
  # fills any orphaned +tool_use+ on the way out with a placeholder
  # +Riffer::Messages::Tool+ carrying +error_type: :interrupted+. The
  # filled call_ids are exposed on
  # +Riffer::Agent::Response#healed_tool_call_ids+ (and the streaming
  # +Riffer::StreamEvents::Interrupt+ event).
  #
  #--
  #: (?(String | Symbol)?) -> void
  def interrupt!(reason = nil)
    throw :riffer_interrupt, reason
  end

  private

  #--
  #: () -> Riffer::Messages::System?
  def build_instruction_message
    content = Riffer::Helpers::CallOrValue.resolve(@config.instructions, context: @context)
    return nil if content.nil? || content.empty?
    Riffer::Messages::System.new(content)
  end

  #--
  #: () -> Riffer::Messages::System?
  def build_skills_message
    skills = @context.skills
    return nil unless skills&.system_prompt
    Riffer::Messages::System.new(skills.system_prompt)
  end

  # Resolves +Config#model+ to a "provider/model" string (calling the Proc
  # form against +@context+), parses it, and looks up the provider class.
  #
  # Returns +[provider_class, model_name]+. Raises Riffer::ArgumentError on
  # an invalid model string or an unregistered provider.
  #
  #--
  #: () -> [singleton(Riffer::Providers::Base), String]
  def resolve_provider_and_model
    model_string = Riffer::Helpers::CallOrValue.resolve(@config.model, context: @context)
    raise Riffer::ArgumentError, "Invalid model string: #{model_string}" unless model_string.is_a?(String)

    provider_name, model_name = model_string.split("/", 2)

    unless provider_name.is_a?(String) && !provider_name.strip.empty? && model_name.is_a?(String) && !model_name.strip.empty?
      raise Riffer::ArgumentError, "Invalid model string: #{model_string}"
    end

    provider_class = Riffer::Providers::Repository.find(provider_name)
    raise Riffer::ArgumentError, "Provider not found: #{provider_name}" unless provider_class

    [provider_class, model_name]
  end

  # Resolves the skills backend, lists skills, and selects an adapter.
  # Returns nil if skills are unconfigured or the backend is empty.
  #
  #--
  #: (singleton(Riffer::Providers::Base)) -> Riffer::Skills::Context?
  def resolve_skills(provider_class)
    skills_config = @config.skills_config
    return nil unless skills_config

    backend = skills_config.backend || Riffer.config.skills.default_backend
    return nil unless backend

    backend = Riffer::Helpers::CallOrValue.resolve(backend, context: @context)
    return nil if backend.list_skills.empty?

    skills = backend.list_skills.to_h { |s| [s.name, s] }
    adapter_class = skills_config.adapter || provider_class.skills_adapter(@model_name)
    skill_activate_tool_class = skills_config.activate_tool || Riffer.config.skills.default_activate_tool

    skills_context = Riffer::Skills::Context.new(
      backend: backend,
      skills: skills,
      adapter: adapter_class.new(skill_activate_tool: skill_activate_tool_class)
    )

    if skills_config.activate
      names = Array(Riffer::Helpers::CallOrValue.resolve(skills_config.activate, context: @context))
      names.each { |name| skills_context.activate(name) }
    end

    skills_context
  end

  #--
  #: () -> Riffer::Agent::StructuredOutput?
  def resolve_structured_output
    params = @config.structured_output
    params ? Riffer::Agent::StructuredOutput.new(params) : nil
  end

  # Resolves the full tool catalog for the agent:
  #
  # - The configured +uses_tools+ value (Proc-form resolved against +context+).
  # - The skill activation tool, when a +skills+ block is configured. The
  #   activation tool class comes from the per-agent +skills do; activate_tool ...; end+
  #   override when set, otherwise from +Riffer.config.skills.default_activate_tool+.
  # - All MCP tools matching any +use_mcp+ tag, optionally wrapped in
  #   AuthenticatedTool when +Riffer.config.mcp.credentials+ is configured.
  #
  # Raises Riffer::ArgumentError on tool name conflicts with the skill
  # activation tool, on duplicate tool names across sources, or on tool
  # classes missing required metadata (description, params).
  #
  #--
  #: () -> Array[singleton(Riffer::Tool)]
  def resolve_tools
    tools = Riffer::Helpers::CallOrValue.resolve(@config.tools_config, context: @context, default: [])

    skills_config = @config.skills_config

    if skills_config
      skill_activate_tool_class = skills_config.activate_tool || Riffer.config.skills.default_activate_tool

      if tools.any? { |t| t.name == skill_activate_tool_class.name }
        raise Riffer::ArgumentError, "Tool name conflict with skill tools: #{skill_activate_tool_class.name}"
      end

      tools += [skill_activate_tool_class]
    end

    tools += resolve_mcp_tool_classes
    assert_distinct_tool_names!(tools)
    tools.each(&:validate_as_tool!)
    tools
  end

  #--
  #: () -> Riffer::Tools::Runtime
  def resolve_tool_runtime
    runtime = Riffer::Helpers::CallOrValue.resolve(@config.tool_runtime, context: @context)
    runtime.is_a?(Class) ? runtime.new : runtime
  end

  #--
  #: () -> Array[singleton(Riffer::Tool)]
  def resolve_mcp_tool_classes
    configs = @config.mcp_configs
    return [] if configs.empty?

    cred = Riffer.config.mcp.credentials
    ctx = @context
    gather_mcp_registrations_with_tags(configs).flat_map do |reg, tag_accum|
      matched_tags = tag_accum.uniq
      mcp_tools_for_registration(reg, matched_tags, cred, ctx)
    end
  end

  # Each matching MCP registration once, with tag symbols unioned across +use_mcp+ rows.
  #
  #: (Array[Hash[Symbol, untyped]]) -> Hash[Riffer::Mcp::Registration, Array[Symbol]]
  def gather_mcp_registrations_with_tags(configs)
    by_reg = {} #: Hash[Riffer::Mcp::Registration, Array[Symbol]]
    configs.each do |cfg|
      Riffer::Mcp::Registry.find_by_tags(cfg[:tags]).each do |reg|
        (by_reg[reg] ||= []).concat(cfg[:tags] & reg.manifest.tags)
      end
    end
    by_reg
  end

  #: (Riffer::Mcp::Registration, Array[Symbol], (^(manifest: Riffer::Mcp::Manifest, matched_tags: Array[Symbol], context: Riffer::Agent::Context) -> Hash[Symbol, untyped]?)?, Riffer::Agent::Context) -> Array[singleton(Riffer::Tool)]
  def mcp_tools_for_registration(reg, matched_tags, cred, ctx)
    return reg.tools unless cred
    return [] if cred.call(manifest: reg.manifest, matched_tags: matched_tags, context: ctx).nil?
    Riffer::Mcp::AuthenticatedTool.wrap_all(reg.tools, reg.manifest, matched_tags)
  end

  # Raises if two or more tool classes share the same +.name+ (ambiguous dispatch).
  #
  #: (Array[singleton(Riffer::Tool)]) -> void
  def assert_distinct_tool_names!(tool_classes)
    tally = Hash.new(0) #: Hash[String, Integer]
    tool_classes.each { |tc| tally[tc.name] += 1 }
    dupes = tally.filter_map { |name, n| name if n > 1 }
    return if dupes.empty?

    raise Riffer::ArgumentError, "Duplicate tool names: #{dupes.sort.join(", ")}"
  end
end
