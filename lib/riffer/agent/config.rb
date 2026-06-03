# frozen_string_literal: true
# rbs_inline: enabled

# Typed configuration object holding every class-level DSL setting on a
# Riffer::Agent subclass.
#
# Each subclass of Riffer::Agent owns one Config, accessible via the class
# method <tt>config</tt>. The class-level DSL (+model+, +instructions+, +uses_tools+,
# etc.) reads and mutates this Config in place. Append-style DSL methods
# (+use_mcp+, +guardrail+) are handled by the +add_mcp+ and +add_guardrail+
# helpers below.
#
# Config stores Procs unresolved. Per-instance resolution happens elsewhere
# (instructions, model, tools, tool runtime, skills).
class Riffer::Agent::Config
  DEFAULT_MAX_STEPS = 16 #: Integer

  attr_reader :identifier #: String?
  attr_reader :model #: (String | Proc)?
  attr_reader :instructions #: (String | Proc)?
  attr_accessor :provider_options #: Hash[Symbol, untyped]
  attr_accessor :model_options #: Hash[Symbol, untyped]
  attr_reader :structured_output #: Riffer::Params?
  attr_accessor :max_steps #: Numeric?
  attr_accessor :tools_config #: (Array[singleton(Riffer::Tool)] | Proc)?
  attr_reader :mcp_configs #: Array[Hash[Symbol, untyped]]
  attr_reader :tool_runtime #: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)
  attr_accessor :skills_config #: Riffer::Skills::Config?
  attr_reader :guardrails #: Hash[Symbol, Array[Hash[Symbol, untyped]]]

  # Builds a new Config. All fields are optional; unset fields take the
  # documented defaults.
  #
  # Raises Riffer::ArgumentError if +model+ or +instructions+ is provided
  # as a non-String, non-Proc value (or as an empty String).
  #
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
    guardrails: {before: [], after: []}
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

  # Sets +identifier+. Accepts +nil+ or any value, coerced to String.
  #
  #--
  #: (untyped) -> String?
  def identifier=(value)
    @identifier = value&.to_s
  end

  # Sets +structured_output+. Accepts a Riffer::Params instance or +nil+.
  #
  # Raises Riffer::ArgumentError on any other type.
  #
  #--
  #: (Riffer::Params?) -> Riffer::Params?
  def structured_output=(value)
    raise Riffer::ArgumentError, "structured_output must be a Riffer::Params" unless value.nil? || value.is_a?(Riffer::Params)
    @structured_output = value
  end

  # Sets +tool_runtime+. Accepts a Riffer::Tools::Runtime subclass, a
  # Riffer::Tools::Runtime instance, or a Proc.
  #
  # Raises Riffer::ArgumentError on any other type.
  #
  #--
  #: ((singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)) -> (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)
  def tool_runtime=(value)
    valid = (value.is_a?(Class) && value < Riffer::Tools::Runtime) || value.is_a?(Riffer::Tools::Runtime) || value.is_a?(Proc)
    raise Riffer::ArgumentError, "tool_runtime must be a Riffer::Tools::Runtime subclass, instance, or a Proc" unless valid
    @tool_runtime = value
  end

  # Sets +model+. Accepts a String ("provider/model"), a Proc, or +nil+.
  #
  # Raises Riffer::ArgumentError on non-String, non-Proc, or empty-String values.
  #
  #--
  #: ((String | Proc)?) -> (String | Proc)?
  def model=(value)
    validate_string_or_proc!(value, "model")
    @model = value
  end

  # Sets +instructions+. Accepts a String, a Proc, or +nil+.
  #
  # Raises Riffer::ArgumentError on non-String, non-Proc, or empty-String values.
  #
  #--
  #: ((String | Proc)?) -> (String | Proc)?
  def instructions=(value)
    validate_string_or_proc!(value, "instructions")
    @instructions = value
  end

  # Appends an MCP tag entry to +mcp_configs+.
  #
  #--
  #: (String | Symbol) -> Array[Hash[Symbol, untyped]]
  def add_mcp(tag)
    @mcp_configs << {tags: [tag.to_sym]}
  end

  # Appends a guardrail entry to +guardrails+ for the given phase.
  #
  # [phase] +:before+, +:after+, or +:around+. +:around+ appends to both
  #   +:before+ and +:after+.
  # [klass] the Riffer::Guardrail subclass to register.
  # [options] options forwarded to the guardrail at runtime.
  #
  # Raises Riffer::ArgumentError on an invalid phase or non-Guardrail class.
  #
  #--
  #: (Symbol, klass: singleton(Riffer::Guardrail), ?options: Hash[Symbol, untyped]) -> void
  def add_guardrail(phase, klass:, options: {})
    valid_phases = [*Riffer::Guardrails::PHASES, :around]
    raise Riffer::ArgumentError, "Invalid guardrail phase: #{phase}" unless valid_phases.include?(phase)
    raise Riffer::ArgumentError, "Guardrail must be a Riffer::Guardrail subclass" unless klass.is_a?(Class) && klass <= Riffer::Guardrail

    cfg = {class: klass, options: options}
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

  #: (untyped, String) -> void
  def validate_string_or_proc!(value, name)
    return if value.nil? || value.is_a?(Proc)
    raise Riffer::ArgumentError, "#{name} must be a String" unless value.is_a?(String)
    raise Riffer::ArgumentError, "#{name} cannot be empty" if value.strip.empty?
  end
end
