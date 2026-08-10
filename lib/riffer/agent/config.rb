# frozen_string_literal: true
# rbs_inline: enabled

# Typed configuration object holding every class-level DSL setting on a
# Riffer::Agent subclass. Procs are stored unresolved and resolved per-instance
# later.
class Riffer::Agent::Config
  DEFAULT_MAX_STEPS = 16 #: Integer

  # The configured agent identifier.
  attr_reader :identifier #: String?

  # The configured model.
  attr_reader :model #: (String | Proc)?

  # The configured instructions.
  attr_reader :instructions #: (String | Proc)?

  # Options passed to the provider client.
  attr_accessor :provider_options #: Hash[Symbol, untyped]

  # Options passed to generate_text/stream_text.
  attr_accessor :model_options #: Hash[Symbol, untyped]

  # The configured structured-output schema.
  attr_reader :structured_output #: Riffer::Params?

  # The maximum number of LLM call steps in the tool-use loop.
  attr_accessor :max_steps #: Numeric?

  # The configured tools.
  attr_accessor :tools_config #: (Array[singleton(Riffer::Tool)] | Proc)?

  # The accumulated +use_mcp+ tag configurations.
  attr_reader :mcp_configs #: Array[Hash[Symbol, untyped]]

  # The configured tool runtime.
  attr_reader :tool_runtime #: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)

  # The configured skills.
  attr_accessor :skills_config #: Riffer::Skills::Config?

  # Registered guardrail entries keyed by phase.
  attr_reader :guardrails #: Hash[Symbol, Array[Hash[Symbol, untyped]]]

  # Builds a new Config. Raises Riffer::ArgumentError if +model+ or
  # +instructions+ is invalid (e.g. an empty string).
  #--
  #: (?identifier: String?, ?model: (String | Proc)?, ?instructions: (String | Proc)?, ?provider_options: Hash[Symbol, untyped], ?model_options: Hash[Symbol, untyped], ?structured_output: Riffer::Params?, ?max_steps: Numeric?, ?tools_config: (Array[singleton(Riffer::Tool)] | Proc)?, ?mcp_configs: Array[Hash[Symbol, untyped]], ?tool_runtime: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc), ?skills_config: Riffer::Skills::Config?, ?guardrails: Hash[Symbol, Array[Hash[Symbol, untyped]]]) -> void
  def initialize(
    identifier: nil,
    model: nil,
    instructions: nil,
    provider_options: {},
    model_options: {},
    structured_output: nil,
    max_steps: DEFAULT_MAX_STEPS,
    tools_config: nil,
    mcp_configs: [],
    tool_runtime: Riffer.config.tool_runtime,
    skills_config: nil,
    guardrails: { before: [], after: [] }
  )
    @provider_options = provider_options
    @model_options = model_options
    @max_steps = max_steps
    @tools_config = tools_config
    @mcp_configs = mcp_configs
    @skills_config = skills_config
    @guardrails = guardrails
    self.identifier = identifier
    self.model = model
    self.instructions = instructions
    self.structured_output = structured_output
    self.tool_runtime = tool_runtime
  end

  # Sets +identifier+, coercing the value to String.
  #--
  #: (untyped) -> String?
  def identifier=(value)
    @identifier = value&.to_s
  end

  # Sets +structured_output+. Raises Riffer::ArgumentError on an invalid value.
  #--
  #: (Riffer::Params?) -> Riffer::Params?
  def structured_output=(value)
    unless value.nil? || value.is_a?(Riffer::Params)
      raise Riffer::ArgumentError, "structured_output must be a Riffer::Params"
    end

    @structured_output = value
  end

  # Sets +tool_runtime+. Raises Riffer::ArgumentError on an invalid value.
  #--
  #: ((singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)) -> (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)
  def tool_runtime=(value)
    valid = (value.is_a?(Class) && value < Riffer::Tools::Runtime) ||
            value.is_a?(Riffer::Tools::Runtime) || value.is_a?(Proc)
    unless valid
      raise Riffer::ArgumentError,
            "tool_runtime must be a Riffer::Tools::Runtime subclass, instance, or a Proc"
    end

    @tool_runtime = value
  end

  # Sets +model+. Raises Riffer::ArgumentError on an invalid value (e.g. an
  # empty string).
  #--
  #: ((String | Proc)?) -> (String | Proc)?
  def model=(value)
    validate_string_or_proc!(value, "model")
    @model = value
  end

  # Sets +instructions+. Raises Riffer::ArgumentError on an invalid value (e.g.
  # an empty string).
  #--
  #: ((String | Proc)?) -> (String | Proc)?
  def instructions=(value)
    validate_string_or_proc!(value, "instructions")
    @instructions = value
  end

  # Appends an MCP tag entry to +mcp_configs+.
  #
  #--
  #: (String | Symbol, ?progressive: bool) -> Array[Hash[Symbol, untyped]]
  def add_mcp(tag, progressive: true)
    raise Riffer::ArgumentError, "progressive must be a boolean" unless [true, false].include?(progressive)

    @mcp_configs << { tags: [tag.to_sym], progressive: progressive }
  end

  # Appends a guardrail entry to +guardrails+ for the given phase; +:around+
  # appends to both +:before+ and +:after+. Raises Riffer::ArgumentError unless
  # +phase+ is :before, :after, or :around.
  #--
  #: (Symbol, klass: singleton(Riffer::Guardrail), ?options: Hash[Symbol, untyped]) -> void
  def add_guardrail(phase, klass:, options: {})
    valid_phases = [*Riffer::Guardrails::PHASES, :around]
    raise Riffer::ArgumentError, "Invalid guardrail phase: #{phase}" unless valid_phases.include?(phase)
    unless klass.is_a?(Class) && klass <= Riffer::Guardrail
      raise Riffer::ArgumentError,
            "Guardrail must be a Riffer::Guardrail subclass"
    end

    cfg = { class: klass, options: options }
    case phase
    when :before
      @guardrails[:before] << cfg
    when :after
      @guardrails[:after] << cfg
    when :around
      @guardrails[:before] << cfg
      @guardrails[:after] << cfg
    end
  end

  # Returns the guardrail entries for the given phase, or +[]+ if none.
  #
  #--
  #: (Symbol) -> Array[Hash[Symbol, untyped]]
  def guardrails_for(phase)
    @guardrails[phase] || []
  end

  private

  #--
  #: (untyped, String) -> void
  def validate_string_or_proc!(value, name)
    return if value.nil? || value.is_a?(Proc)
    raise Riffer::ArgumentError, "#{name} must be a String" unless value.is_a?(String)
    raise Riffer::ArgumentError, "#{name} cannot be empty" if value.strip.empty?
  end
end
