# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Turns a resolved agent into a self-contained, provider-neutral data hash and
# back into a runnable agent, behind the +Riffer::Agent#to_h+ /
# +Riffer::Agent.from_h+ delegators.
#
#   hash    = Riffer::Agent::Serializer.to_h(agent: agent)
#   rebuilt = Riffer::Agent::Serializer.from_h(hash, context: {tenant: "acme"})
module Riffer::Agent::Serializer
  extend self

  # The wire format version, bumped only on an incompatible change to the hash
  # shape; +from_h+ refuses any other version.
  SCHEMA_VERSION = 1 #: Integer

  # Raised by +from_h+ when the hash's +schema_version+ is unsupported.
  class VersionError < Riffer::ArgumentError; end

  # The default +tool_resolver+: synthesizes a body-less tool shell from a
  # descriptor. Its +#call+ raises — route shells through a remote runtime.
  DEFAULT_TOOL_RESOLVER = ->(descriptor) { build_tool_shell(descriptor) } #: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool)

  # Snapshots a resolved agent into a self-contained wire hash. Proc-based
  # settings are already evaluated against the agent's context, so the hash
  # carries plain data, never Procs.
  #--
  #: (agent: Riffer::Agent) -> Hash[Symbol, untyped]
  def to_h(agent:)
    config = agent.config
    {
      schema_version: SCHEMA_VERSION,
      riffer_version: Riffer::VERSION,
      identifier: config.identifier,
      model: "#{agent.provider_name}/#{agent.model_name}",
      instructions: agent.instruction_message&.content,
      model_options: config.model_options,
      max_steps: encode_max_steps(config.max_steps),
      structured_output: config.structured_output&.to_json_schema(strict: false),
      tools: agent.tools.map { |tool_class| tool_descriptor(tool_class) },
    }
  end

  # Reconstructs a runnable agent from a wire hash. +context+ is threaded into
  # tool dispatch (not used to re-resolve the already-resolved config);
  # +session+ seeds conversation history (the hash carries the agent definition,
  # not its history). Raises Riffer::Agent::Serializer::VersionError on an
  # unsupported +schema_version+.
  #
  #--
  #: (Hash[Symbol, untyped], ?context: Hash[Symbol, untyped]?, ?session: Riffer::Agent::Session?, ?tool_resolver: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool), ?tool_runtime: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> Riffer::Agent
  def from_h(hash, context: nil, session: nil, tool_resolver: DEFAULT_TOOL_RESOLVER, tool_runtime: nil)
    # Version -> decoder dispatch. Adding a +when 2+ arm (a backwards-compatible
    # decoder) is how a future breaking change keeps older hashes readable.
    case hash[:schema_version]
    when SCHEMA_VERSION
      decode_v1(hash, context: context, session: session, tool_resolver: tool_resolver, tool_runtime: tool_runtime)
    else
      raise VersionError,
            "Unsupported schema_version: #{hash[:schema_version].inspect} (this Riffer supports #{SCHEMA_VERSION})"
    end
  end

  # Snapshots a resolved agent to a JSON string.
  #--
  #: (agent: Riffer::Agent) -> String
  def to_json(agent:)
    JSON.generate(to_h(agent: agent))
  end

  # Reconstructs a runnable agent from a JSON string produced by +to_json+. See
  # +from_h+ for the arguments.
  #--
  #: (String, ?context: Hash[Symbol, untyped]?, ?session: Riffer::Agent::Session?, ?tool_resolver: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool), ?tool_runtime: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> Riffer::Agent
  def from_json(json, context: nil, session: nil, tool_resolver: DEFAULT_TOOL_RESOLVER, tool_runtime: nil)
    from_h(
      JSON.parse(json, symbolize_names: true),
      context: context,
      session: session,
      tool_resolver: tool_resolver,
      tool_runtime: tool_runtime,
    )
  end

  private

  #--
  #: (Hash[Symbol, untyped], context: Hash[Symbol, untyped]?, session: Riffer::Agent::Session?, tool_resolver: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool), tool_runtime: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> Riffer::Agent
  def decode_v1(hash, context:, session:, tool_resolver:, tool_runtime:)
    tools = Array(hash[:tools]).map { |descriptor| tool_resolver.call(descriptor) }

    config_args = {
      identifier: hash[:identifier],
      model: hash[:model],
      instructions: hash[:instructions],
      model_options: hash[:model_options] || {},
      structured_output: decode_structured_output(hash[:structured_output]),
      max_steps: decode_max_steps(hash),
      tools_config: tools,
    } #: Hash[Symbol, untyped]
    # tool_runtime= rejects nil, so only inject when supplied; otherwise the
    # Config default (Riffer.config.tool_runtime) applies.
    config_args[:tool_runtime] = tool_runtime if tool_runtime

    # +session+ is forwarded verbatim: when nil, Agent.new seeds a fresh session
    # from the decoded instructions; when supplied, Agent.new uses it as-is to
    # resume persisted history. The hash never carries history (see "What does
    # not transfer"), so this is the only seam for rehydrating a conversation.
    Riffer::Agent.new(config: Riffer::Agent::Config.new(**config_args), context: context, session: session)
  end

  #--
  #: (Hash[Symbol, untyped]?) -> Riffer::Params?
  def decode_structured_output(schema)
    return nil if schema.nil?

    Riffer::Params.from_json_schema(schema)
  end

  # Encodes unlimited steps (+nil+ in the DSL) as +-1+ on the wire, where a
  # JSON +null+ is awkward across transports (e.g. proto3).
  #--
  #: (Numeric?) -> Numeric
  def encode_max_steps(value)
    value.nil? ? -1 : value
  end

  # Reverses +encode_max_steps+; a missing key falls back to the default so a
  # partial hash can't become an unbounded loop.
  #--
  #: (Hash[Symbol, untyped]) -> Numeric?
  def decode_max_steps(hash)
    return Riffer::Agent::Config::DEFAULT_MAX_STEPS unless hash.key?(:max_steps)

    hash[:max_steps] == -1 ? nil : hash[:max_steps]
  end

  #--
  #: (singleton(Riffer::Tool)) -> Hash[Symbol, untyped]
  def tool_descriptor(tool_class)
    tool_class.to_tool_schema(strict: false).merge(timeout: tool_class.timeout)
  end

  #--
  #: (Hash[Symbol, untyped]) -> untyped
  def build_tool_shell(descriptor)
    tool_name = descriptor[:name]
    tool_description = descriptor[:description]
    schema = descriptor[:parameters_schema]
    tool_timeout = descriptor[:timeout]

    # An anonymous Riffer::Tool subclass is the idiom for synthesizing a tool
    # from data — the tool DSL is class-level, so there is no value-level
    # builder to type against. Same approach as Riffer::Mcp::ToolFactory;
    # steep can't type the dynamic class body, hence the ignore block.
    Class.new(Riffer::Tool) do
      # steep:ignore:start
      identifier tool_name
      description tool_description
      timeout tool_timeout if tool_timeout
      define_singleton_method(:parameters_schema) { |strict: false| schema }

      define_method(:call) do |context:, **_kwargs|
        raise Riffer::Error,
              "#{self.class.name || 'wire tool shell'} '#{self.class.identifier}' has no body; " \
              "route its calls through a remote Riffer::Tools::Runtime (see Riffer::Agent::Serializer)"
      end
      # steep:ignore:end
    end
  end
end
