# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Base class for all agents in the Riffer framework. Subclass it to define an
# agent's model, instructions, tools, and guardrails.
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

  INTERRUPT_MAX_STEPS = :max_steps #: Symbol

  # Returns the per-class Riffer::Agent::Config holding every DSL setting.
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
    value.nil? ? (config.identifier || Riffer::Helpers::ClassNameConverter.convert(name)) : (config.identifier = value)
  end

  # Gets or sets the model string (e.g., "openai/gpt-4o").
  #
  #--
  #: (?(String | Proc)?) -> (String | Proc)?
  def self.model(value = nil)
    value.nil? ? config.model : (config.model = value)
  end

  # Gets or sets the agent instructions. A Proc is called at generate time with
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
  # The splat distinguishes a getter (no argument) from setting the limit to
  # +nil+ (unlimited); it defaults to Riffer::Agent::Config::DEFAULT_MAX_STEPS.
  #
  #   max_steps        # reads the current limit
  #   max_steps 8      # cap the loop at 8 steps
  #   max_steps nil    # unlimited
  #
  #--
  #: (*Numeric?) -> Numeric?
  def self.max_steps(*value)
    return config.max_steps if value.empty?
    config.max_steps = value.first
  end

  # Gets or sets the tools used by this agent.
  #
  #--
  #: (?(Array[singleton(Riffer::Tool)] | Proc)?) -> (Array[singleton(Riffer::Tool)] | Proc)?
  def self.uses_tools(value = nil)
    value.nil? ? config.tools_config : (config.tools_config = value)
  end

  # Returns the tool classes the LLM should see for this agent.
  #
  # Class-level companion to the instance +#tools+. Resolves the Proc form
  # of +uses_tools+ and appends the skill activation tool when a +skills+
  # block is configured. Does not include MCP tools — those require a live
  # registry and per-instance context.
  #
  # When +uses_tools+ is a Proc, +context+ is forwarded to it.
  #
  # Each returned tool class is validated via +validate_as_tool!+.
  #
  # Raises Riffer::ArgumentError on tool name conflicts with the skill
  # activation tool, or when a tool class fails +validate_as_tool!+.
  #
  #--
  #: (?context: Hash[Symbol, untyped]?, ?config: Riffer::Agent::Config) -> Array[singleton(Riffer::Tool)]
  def self.resolved_tool_classes(context: nil, config: self.config)
    base = Riffer::Helpers::CallOrValue.resolve(config.tools_config, context: context, default: [])
    skills_cfg = config.skills_config

    tools = if skills_cfg
      skill_activate_tool_class = skills_cfg.activate_tool || Riffer.config.skills.default_activate_tool
      if base.any? { |t| t.name == skill_activate_tool_class.name }
        raise Riffer::ArgumentError, "Tool name conflict with skill tools: #{skill_activate_tool_class.name}"
      end
      base + [skill_activate_tool_class]
    else
      base
    end

    tools.each(&:validate_as_tool!)
    tools
  end

  # Opts this agent into tools from all MCP registrations that share any of
  # the given tag(s).
  #
  # +tag+ - a String or Symbol; matched against registration manifest tags.
  # +progressive+ - when +false+, all tools from matching registrations are
  #   injected directly (opt-out of context-saving). Defaults to +true+: tools
  #   are exposed via +mcp_search+ and +mcp_call+ meta-tools
  #   and the LLM discovers and invokes them on demand.
  #
  #: (String | Symbol, ?progressive: bool) -> void
  def self.use_mcp(tag, progressive: true)
    config.add_mcp(tag, progressive: progressive)
  end

  # Returns the accumulated +use_mcp+ configurations for this agent class.
  #
  #: () -> Array[Hash[Symbol, untyped]]
  def self.mcp_configs
    config.mcp_configs
  end

  # Gets or sets the tool runtime for this agent; defaults to
  # <tt>Riffer.config.tool_runtime</tt> when unset.
  #--
  #: (?(singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)
  def self.tool_runtime(value = nil)
    value.nil? ? config.tool_runtime : (config.tool_runtime = value)
  end

  # Configures skills for this agent via a block DSL, or returns the current
  # Riffer::Skills::Config when called without a block.
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
  #--
  #: (?String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?, ?context: Hash[Symbol, untyped]?) -> Riffer::Agent::Response
  def self.generate(prompt = nil, files: nil, context: nil)
    new(context: context).generate(prompt, files: files)
  end

  # Streams a response using a new agent instance.
  #--
  #: (?String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?, ?context: Hash[Symbol, untyped]?) -> Enumerator[Riffer::StreamEvents::Base, void]
  def self.stream(prompt = nil, files: nil, context: nil)
    new(context: context).stream(prompt, files: files)
  end

  # Reconstructs a runnable agent from a wire hash produced by +#to_h+.
  #--
  #: (Hash[Symbol, untyped], ?context: Hash[Symbol, untyped]?, ?session: Riffer::Agent::Session?, ?tool_resolver: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool), ?tool_runtime: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> Riffer::Agent
  def self.from_h(hash, context: nil, session: nil, tool_resolver: Riffer::Agent::Serializer::DEFAULT_TOOL_RESOLVER, tool_runtime: nil)
    Riffer::Agent::Serializer.from_h(hash, context: context, session: session, tool_resolver: tool_resolver, tool_runtime: tool_runtime)
  end

  # Reconstructs a runnable agent from a JSON string produced by +#to_json+.
  #--
  #: (String, ?context: Hash[Symbol, untyped]?, ?session: Riffer::Agent::Session?, ?tool_resolver: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool), ?tool_runtime: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> Riffer::Agent
  def self.from_json(json, context: nil, session: nil, tool_resolver: Riffer::Agent::Serializer::DEFAULT_TOOL_RESOLVER, tool_runtime: nil)
    Riffer::Agent::Serializer.from_json(json, context: context, session: session, tool_resolver: tool_resolver, tool_runtime: tool_runtime)
  end

  # Registers a guardrail for input, output, or both phases. Raises
  # Riffer::ArgumentError unless +phase+ is :before, :after, or :around.
  #--
  #: (Symbol, with: singleton(Riffer::Guardrail), **untyped) -> void
  def self.guardrail(phase, with:, **options)
    config.add_guardrail(phase, klass: with, options: options)
  end

  # Returns the registered guardrail configs for a given phase.
  #--
  #: (Symbol) -> Array[Hash[Symbol, untyped]]
  def self.guardrails_for(phase)
    config.guardrails_for(phase)
  end

  # The conversation handle.
  attr_reader :session #: Riffer::Agent::Session

  # The per-instance Riffer::Agent::Config.
  attr_reader :config #: Riffer::Agent::Config

  # The system message built from the configured +instructions+, or +nil+ when
  # none are configured.
  attr_reader :instruction_message #: Riffer::Messages::System?

  # The system message describing the configured skills catalog, or +nil+ when
  # skills are unconfigured or the catalog is empty.
  attr_reader :skills_message #: Riffer::Messages::System?

  # The mutable runtime context shared with every +Riffer::Agent::Run+ this
  # agent executes and threaded through all Proc-based settings.
  attr_reader :context #: Riffer::Agent::Context

  # The resolved provider name (the part before "/" in the model string),
  # e.g. +"openai"+.
  attr_reader :provider_name #: String

  # The resolved model name (the part after "/" in the model string), used as
  # the model argument on every LLM call.
  attr_reader :model_name #: String

  # The provider client. Public so tests can pre-queue responses on
  # +Riffer::Providers::Mock+ before calling +#generate+.
  attr_reader :provider #: Riffer::Providers::Base

  # The +Riffer::Agent::StructuredOutput+ wrapping the configured schema, or
  # +nil+ when not configured.
  attr_reader :structured_output #: Riffer::Agent::StructuredOutput?

  # The tool classes the LLM sees on every call this agent makes.
  attr_reader :tools #: Array[singleton(Riffer::Tool)]

  # The tool runtime instance used to execute tool calls.
  attr_reader :tool_runtime #: Riffer::Tools::Runtime

  # Initializes a new agent.
  #
  # A provided +session:+ is used as-is — the caller owns its contents (e.g.
  # cross-process resume from persisted history); an omitted one is seeded with
  # the instruction and skills messages.
  #
  # Raises Riffer::ArgumentError unless the configured model string is
  # "provider/model" format.
  #
  #--
  #: (?session: Riffer::Agent::Session?, ?context: Hash[Symbol, untyped]?, ?config: Riffer::Agent::Config?) -> void
  def initialize(session: nil, context: nil, config: nil)
    @config = config || self.class.config
    @context = Riffer::Agent::Context.new(context || {})

    @provider_name, @model_name = resolve_provider_and_model
    @provider = build_provider

    @context.skills = resolve_skills

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
  # With +prompt+, a new user message is appended (silently — +on_message+ does
  # not fire for user inputs) before the loop runs. Without it, the loop runs
  # against the current session, resuming a persisted conversation or pending
  # tool calls. +files:+ requires +prompt+.
  #
  #--
  #: (?String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?) -> Riffer::Agent::Response
  def generate(prompt = nil, files: nil)
    Riffer::Agent::Run.generate(agent: self, prompt: prompt, files: files)
  end

  # Streams a response from the agent, returning an +Enumerator+ of
  # +Riffer::StreamEvents+. See +#generate+ for prompt/files semantics.
  #
  # Raises Riffer::ArgumentError if structured output is configured.
  #
  #--
  #: (?String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?) -> Enumerator[Riffer::StreamEvents::Base, void]
  def stream(prompt = nil, files: nil)
    raise Riffer::ArgumentError, "Structured output is not supported with streaming. Use #generate instead." if @structured_output
    Riffer::Agent::Run.stream(agent: self, prompt: prompt, files: files)
  end

  # Interrupts the agent loop from an +on_message+ callback. Equivalent to
  # <tt>throw :riffer_interrupt, reason</tt>.
  #--
  #: (?(String | Symbol)?) -> void
  def interrupt!(reason = nil)
    throw :riffer_interrupt, reason
  end

  # Snapshots this resolved agent into a self-contained, provider-neutral wire
  # hash.
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    Riffer::Agent::Serializer.to_h(agent: self)
  end

  # Snapshots this resolved agent into a wire JSON string. The +*+ absorbs the
  # JSON generator state argument so <tt>JSON.generate(agent)</tt> works too.
  #--
  #: (*untyped) -> String
  def to_json(*)
    Riffer::Agent::Serializer.to_json(agent: self)
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

  #--
  #: () -> [String, String]
  def resolve_provider_and_model
    model_string = Riffer::Helpers::CallOrValue.resolve(@config.model, context: @context)
    raise Riffer::ArgumentError, "Invalid model string: #{model_string}" unless model_string.is_a?(String)

    provider_name, model_name = model_string.split("/", 2)

    unless provider_name.is_a?(String) && !provider_name.strip.empty? && model_name.is_a?(String) && !model_name.strip.empty?
      raise Riffer::ArgumentError, "Invalid model string: #{model_string}"
    end

    [provider_name, model_name]
  end

  #--
  #: () -> Riffer::Providers::Base
  def build_provider
    provider_class = Riffer::Providers::Repository.find(@provider_name)
    raise Riffer::ArgumentError, "Provider not found: #{@provider_name}" unless provider_class
    provider_class.new(**@config.provider_options)
  end

  #--
  #: () -> Riffer::Skills::Context?
  def resolve_skills
    skills_config = @config.skills_config
    return nil unless skills_config

    backend = skills_config.backend || Riffer.config.skills.default_backend
    return nil unless backend

    backend = Riffer::Helpers::CallOrValue.resolve(backend, context: @context)
    return nil if backend.list_skills.empty?

    skills = backend.list_skills.to_h { |s| [s.name, s] }
    adapter_class = skills_config.adapter || @provider.class.skills_adapter(@model_name)
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

    regular_reg_tags, progressive_reg_tags = gather_mcp_registrations_with_tags(configs)

    regular_tools = regular_reg_tags.flat_map { |reg, tag_accum| mcp_tools_for_registration(reg, tag_accum.uniq, cred, ctx) }
    progressive_tools = progressive_reg_tags.flat_map { |reg, tag_accum| mcp_tools_for_registration(reg, tag_accum.uniq, cred, ctx) }

    if progressive_tools.any?
      @context.mcp_progressive_tools = progressive_tools.freeze
      regular_tools + [Riffer::Mcp::SearchTool, Riffer::Mcp::CallTool]
    else
      regular_tools
    end
  end

  # Each matching MCP registration once, split by the +:progressive+ flag,
  # with tag symbols unioned across +use_mcp+ rows.
  #
  # Returns +[regular, progressive]+ — two Hashes mapping a registration to
  # its accumulated matched tags.
  #
  #: (Array[Hash[Symbol, untyped]]) -> [Hash[Riffer::Mcp::Registration, Array[Symbol]], Hash[Riffer::Mcp::Registration, Array[Symbol]]]
  def gather_mcp_registrations_with_tags(configs)
    regular = {} #: Hash[Riffer::Mcp::Registration, Array[Symbol]]
    progressive = {} #: Hash[Riffer::Mcp::Registration, Array[Symbol]]
    configs.each do |cfg|
      target = cfg[:progressive] ? progressive : regular
      Riffer::Mcp::Registry.find_by_tags(cfg[:tags]).each do |reg|
        (target[reg] ||= []).concat(cfg[:tags] & reg.manifest.tags)
      end
    end
    [regular, progressive]
  end

  #--
  #: (Riffer::Mcp::Registration, Array[Symbol], (^(manifest: Riffer::Mcp::Manifest, matched_tags: Array[Symbol], context: Riffer::Agent::Context) -> Hash[Symbol, untyped]?)?, Riffer::Agent::Context) -> Array[singleton(Riffer::Tool)]
  def mcp_tools_for_registration(reg, matched_tags, cred, ctx)
    return reg.tools unless cred
    return [] if cred.call(manifest: reg.manifest, matched_tags: matched_tags, context: ctx).nil?
    Riffer::Mcp::AuthenticatedTool.wrap_all(reg.tools, reg.manifest, matched_tags)
  end

  #--
  #: (Array[singleton(Riffer::Tool)]) -> void
  def assert_distinct_tool_names!(tool_classes)
    tally = Hash.new(0) #: Hash[String, Integer]
    tool_classes.each { |tc| tally[tc.name] += 1 }
    dupes = tally.filter_map { |name, n| name if n > 1 }
    return if dupes.empty?

    raise Riffer::ArgumentError, "Duplicate tool names: #{dupes.sort.join(", ")}"
  end
end
