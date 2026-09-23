# frozen_string_literal: true
# rbs_inline: enabled

require "json"

class Riffer::Agent
  extend Riffer::Registrable

  # @rbs self.@config: Riffer::Agent::Config?

  INTERRUPT_MAX_STEPS = :max_steps #: Symbol

  #--
  #: () -> Riffer::Agent::Config
  def self.config
    @config ||= Riffer::Agent::Config.new
  end

  #--
  #: (Class) -> void
  def self.inherited(subclass)
    super
    copy = config.dup
    # The identifier is identity, not inheritable config: two classes claiming
    # one raise Riffer::DuplicateIdentifierError at the next registry lookup.
    copy.identifier = nil
    subclass.instance_variable_set(:@config, copy)
  end
  private_class_method :inherited

  #--
  #: (?String?) -> String
  def self.identifier(value = nil)
    value.nil? ? (config.identifier || Riffer::Helpers::Identifier.for(self)) : (config.identifier = value)
  end

  #--
  #: (?(String | Proc)?) -> (String | Proc)?
  def self.model(value = nil)
    value.nil? ? config.model : (config.model = value)
  end

  #--
  #: (?(String | Proc)?) -> (String | Proc)?
  def self.instructions(value = nil)
    value.nil? ? config.instructions : (config.instructions = value)
  end

  #--
  #: (?Hash[Symbol, untyped]?) -> Hash[Symbol, untyped]
  def self.model_options(options = nil)
    options.nil? ? config.model_options : (config.model_options = options)
  end

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

  #--
  #: (*Numeric?) -> Numeric?
  def self.max_steps(*value)
    # The splat tells a bare read apart from +max_steps nil+ (unlimited).
    return config.max_steps if value.empty?

    config.max_steps = value.first
  end

  #--
  #: (?(Array[singleton(Riffer::Tool)] | Proc)?) -> (Array[singleton(Riffer::Tool)] | Proc)?
  def self.uses_tools(value = nil)
    value.nil? ? config.tools_config : (config.tools_config = value)
  end

  # +progressive+ exposes +mcp_search+ instead of every tool schema up front.
  #--
  #: (String | Symbol, ?progressive: bool) -> void
  def self.use_mcp(tag, progressive: true)
    config.add_mcp(tag, progressive: progressive)
  end

  #: () -> Array[Hash[Symbol, untyped]]
  def self.mcp_configs
    config.mcp_configs
  end

  #--
  #: (?(singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)
  def self.tool_runtime(value = nil)
    value.nil? ? config.tool_runtime : (config.tool_runtime = value)
  end

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

  #--
  #: (?String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::User::FilePart]?, ?context: Hash[Symbol, untyped]?, ?tags: Hash[(String | Symbol), untyped]) -> Riffer::Agent::Response
  def self.generate(prompt = nil, files: nil, context: nil, tags: {})
    new(context: context).generate(prompt, files: files, tags: tags)
  end

  #--
  #: (?String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::User::FilePart]?, ?context: Hash[Symbol, untyped]?, ?tags: Hash[(String | Symbol), untyped]) -> Enumerator[Riffer::StreamEvents::Base, Riffer::Agent::Response]
  def self.stream(prompt = nil, files: nil, context: nil, tags: {})
    new(context: context).stream(prompt, files: files, tags: tags)
  end

  #--
  #: (Hash[Symbol, untyped], ?context: Hash[Symbol, untyped]?, ?session: Riffer::Agent::Session?, ?tool_resolver: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool), ?tool_runtime: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> Riffer::Agent
  def self.from_h(
    hash,
    context: nil,
    session: nil,
    tool_resolver: Riffer::Agent::Serializer::DEFAULT_TOOL_RESOLVER,
    tool_runtime: nil
  )
    Riffer::Agent::Serializer.from_h(
      hash,
      context: context,
      session: session,
      tool_resolver: tool_resolver,
      tool_runtime: tool_runtime,
    )
  end

  #--
  #: (String, ?context: Hash[Symbol, untyped]?, ?session: Riffer::Agent::Session?, ?tool_resolver: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool), ?tool_runtime: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> Riffer::Agent
  def self.from_json(
    json,
    context: nil,
    session: nil,
    tool_resolver: Riffer::Agent::Serializer::DEFAULT_TOOL_RESOLVER,
    tool_runtime: nil
  )
    Riffer::Agent::Serializer.from_json(
      json,
      context: context,
      session: session,
      tool_resolver: tool_resolver,
      tool_runtime: tool_runtime,
    )
  end

  #--
  #: (Symbol, with: singleton(Riffer::Guardrail), **untyped) -> void
  def self.guardrail(phase, with:, **options)
    config.add_guardrail(phase, klass: with, options: options)
  end

  #--
  #: (Symbol) -> Array[Hash[Symbol, untyped]]
  def self.guardrails_for(phase)
    config.guardrails_for(phase)
  end

  attr_reader :session #: Riffer::Agent::Session # @dynamic session
  attr_reader :config #: Riffer::Agent::Config # @dynamic config
  attr_reader :instruction_message #: Riffer::Messages::System? # @dynamic instruction_message
  attr_reader :skills_message #: Riffer::Messages::System? # @dynamic skills_message
  attr_reader :context #: Riffer::Agent::Context # @dynamic context
  attr_reader :provider_name #: String # @dynamic provider_name
  attr_reader :model_name #: String # @dynamic model_name

  # Public so tests can pre-queue responses on Riffer::Providers::Mock.
  attr_reader :provider #: Riffer::Providers::Base # @dynamic provider

  attr_reader :structured_output #: Riffer::Agent::StructuredOutput? # @dynamic structured_output
  attr_reader :tools #: Array[singleton(Riffer::Tool)] # @dynamic tools
  attr_reader :tool_runtime #: Riffer::Tools::Runtime # @dynamic tool_runtime

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

    # A caller-supplied session owns its contents (e.g. resumed history), so it
    # is not seeded.
    @session = session || Riffer::Agent::Session.new(messages: [@instruction_message, @skills_message].compact)
    @session.set(Riffer::Agent::Session::Repair.prune_orphans(@session.messages))
  end

  #--
  #: () -> String
  def identifier
    config.identifier || self.class.identifier
  end

  #--
  #: (?String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::User::FilePart]?, ?tags: Hash[(String | Symbol), untyped]) -> Riffer::Agent::Response
  def generate(prompt = nil, files: nil, tags: {})
    Riffer::Agent::Run.generate(agent: self, prompt: prompt, files: files, tags: tags)
  end

  #--
  #: (?String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::User::FilePart]?, ?tags: Hash[(String | Symbol), untyped]) -> Enumerator[Riffer::StreamEvents::Base, Riffer::Agent::Response]
  def stream(prompt = nil, files: nil, tags: {})
    if @structured_output
      raise Riffer::ArgumentError,
            "Structured output is not supported with streaming. Use #generate instead."
    end

    Riffer::Agent::Run.stream(agent: self, prompt: prompt, files: files, tags: tags)
  end

  #--
  #: (?(String | Symbol)?) -> void
  def interrupt!(reason = nil)
    throw :riffer_interrupt, reason
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    Riffer::Agent::Serializer.to_h(agent: self)
  end

  # The +*+ absorbs JSON's generator-state argument so
  # <tt>JSON.generate(agent)</tt> works.
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
    content = @context.skills&.system_prompt
    return nil if content.nil? || content.empty?

    Riffer::Messages::System.new(content)
  end

  #--
  #: () -> [String, String]
  def resolve_provider_and_model
    model_string = Riffer::Helpers::CallOrValue.resolve(@config.model, context: @context)
    raise Riffer::ArgumentError, "Invalid model string: #{model_string}" unless model_string.is_a?(String)

    provider_name, model_name = model_string.split("/", 2)

    unless provider_name.is_a?(String) && !provider_name.strip.empty? &&
           model_name.is_a?(String) && !model_name.strip.empty?
      raise Riffer::ArgumentError, "Invalid model string: #{model_string}"
    end

    [provider_name, model_name]
  end

  #--
  #: () -> Riffer::Providers::Base
  def build_provider
    provider_class = Riffer::Providers::Repository.find(@provider_name)
    raise Riffer::ArgumentError, "Provider not found: #{@provider_name}" unless provider_class

    provider_class.new
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
      adapter: adapter_class.new(skill_activate_tool: skill_activate_tool_class),
    )

    if skills_config.activate
      names = Array(Riffer::Helpers::CallOrValue.resolve(skills_config.activate, context: @context))
      names.each { |name| skills_context.preactivate(name) }
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

    if skills_config && @context.skills&.activatable?
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

    regular_tools = regular_reg_tags.flat_map do |reg, tag_accum|
      mcp_tools_for_registration(reg, tag_accum.uniq, cred, ctx)
    end
    progressive_tools = progressive_reg_tags.flat_map do |reg, tag_accum|
      mcp_tools_for_registration(reg, tag_accum.uniq, cred, ctx)
    end

    if progressive_tools.any?
      @context.mcp_progressive_tools = progressive_tools.freeze
      regular_tools + [Riffer::Mcp::SearchTool]
    else
      regular_tools
    end
  end

  #--
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

    raise Riffer::ArgumentError, "Duplicate tool names: #{dupes.sort.join(', ')}"
  end
end
