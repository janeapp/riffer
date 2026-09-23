# frozen_string_literal: true
# rbs_inline: enabled

require "json"

module Riffer::Agent::Serializer
  extend self

  # Bump only on an incompatible change to the hash shape.
  SCHEMA_VERSION = 1 #: Integer

  class VersionError < Riffer::ArgumentError; end

  DEFAULT_TOOL_RESOLVER = ->(descriptor) { build_tool_shell(descriptor) } #: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool)

  #--
  #: (agent: Riffer::Agent) -> Hash[Symbol, untyped]
  def to_h(agent:)
    # Already resolved against the agent's context, so the hash carries plain data, never Procs.
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

  # Raises Riffer::Agent::Serializer::VersionError on an unsupported +schema_version+.
  #--
  #: (Hash[Symbol, untyped], ?context: Hash[Symbol, untyped]?, ?session: Riffer::Agent::Session?, ?tool_resolver: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool), ?tool_runtime: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> Riffer::Agent
  def from_h(hash, context: nil, session: nil, tool_resolver: DEFAULT_TOOL_RESOLVER, tool_runtime: nil)
    # One arm per supported version keeps older hashes decodable after a breaking change.
    case hash[:schema_version]
    when SCHEMA_VERSION
      decode_v1(hash, context: context, session: session, tool_resolver: tool_resolver, tool_runtime: tool_runtime)
    else
      raise VersionError,
            "Unsupported schema_version: #{hash[:schema_version].inspect} (this Riffer supports #{SCHEMA_VERSION})"
    end
  end

  #--
  #: (agent: Riffer::Agent) -> String
  def to_json(agent:)
    JSON.generate(to_h(agent: agent))
  end

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
    # Config#tool_runtime= rejects nil.
    config_args[:tool_runtime] = tool_runtime if tool_runtime

    # The hash never carries history, so +session+ is the only seam for rehydrating a conversation.
    # +context+ feeds tool dispatch only; the config was resolved before serialization.
    Riffer::Agent.new(config: Riffer::Agent::Config.new(**config_args), context: context, session: session)
  end

  #--
  #: (Hash[Symbol, untyped]?) -> Riffer::Params?
  def decode_structured_output(schema)
    return nil if schema.nil?

    Riffer::Params.from_json_schema(schema)
  end

  #--
  #: (Numeric?) -> Numeric
  def encode_max_steps(value)
    # A JSON null is awkward across transports (e.g. proto3), so unlimited travels as -1.
    value.nil? ? -1 : value
  end

  #--
  #: (Hash[Symbol, untyped]) -> Numeric?
  def decode_max_steps(hash)
    # A partial hash must not become an unbounded loop.
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

    # The tool DSL is class-level, so there is no value-level builder to synthesize a tool from data.
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
