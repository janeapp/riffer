# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Riffer::Agent::Serializer turns a resolved agent into a self-contained,
# provider-neutral data dict and back into a runnable agent. A pure module
# (sibling to Riffer::Agent::Run), reached most often through the
# +Riffer::Agent#to_h+ / +Riffer::Agent.from_h+ delegators.
#
# The dict carries only data — no Procs, no class references, no tool
# runtime. The same dict serves two rehydration targets:
#
# - <b>In-process</b> (a monolith persisting agent definitions): pass a
#   +tool_resolver+ that looks tool descriptors up in a local registry and
#   returns the real, body-bearing classes. They run on the default runtime.
# - <b>Distributed</b> (a receiver holding only the Riffer gem): the default
#   resolver synthesizes body-less tool shells; inject a remote
#   +Riffer::Tools::Runtime+ to forward each call back to the origin.
#
#   dict  = Riffer::Agent::Serializer.to_h(agent: agent)
#   rebuilt = Riffer::Agent::Serializer.from_h(dict, context: {tenant: "acme"})
#
# == What does not transfer
#
# Guardrails and the skills subsystem (backend/adapter/catalog) are not
# serialized; a rebuilt agent enforces no guardrails and renders no skills
# catalog (the +skill_activate+ tool, if present, crosses as an ordinary
# tool). Secrets must not be placed in +provider_options+/+model_options+:
# both ride on the wire as plain data.
module Riffer::Agent::Serializer
  extend self

  # The wire format version. Bumped only on an incompatible change to the
  # dict shape; +from_h+ refuses any other version. See +from_h+ for the
  # dispatch seam that carries back-compat decoders.
  SCHEMA_VERSION = 1 #: Integer

  # Raised by +from_h+ when the dict's +schema_version+ is unsupported.
  class VersionError < Riffer::ArgumentError; end

  # The default +tool_resolver+: synthesizes a body-less tool shell from a
  # descriptor. Its +#call+ raises — route shells through a remote runtime.
  DEFAULT_TOOL_RESOLVER = ->(descriptor) { build_tool_shell(descriptor) } #: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool)

  # Snapshots a resolved agent into a self-contained wire dict.
  #
  # Reads the agent's resolved instance state — Proc-based settings have
  # already been evaluated against the agent's own context, so the dict
  # carries plain strings/data, never Procs. Tools are emitted as
  # +{name, description, parameters_schema, timeout}+ descriptors (the
  # resolved +agent.tools+, including MCP tools and +skill_activate+).
  #
  # [agent] a resolved Riffer::Agent instance.
  #
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
      provider_options: config.provider_options,
      max_steps: config.max_steps,
      structured_output: config.structured_output&.to_json_schema(strict: false),
      tools: agent.tools.map { |tool_class| tool_descriptor(tool_class) }
    }
  end

  # Reconstructs a runnable agent from a wire dict.
  #
  # [hash] a Symbol-keyed wire dict (parse JSON with +symbolize_names: true+).
  # [context] the runtime context for the rebuilt agent; drives tool
  #   dispatch and any per-call concerns. Not serialized — supplied here.
  # [tool_resolver] maps a tool descriptor to a Riffer::Tool class. Defaults
  #   to DEFAULT_TOOL_RESOLVER (body-less shells). Pass a registry lookup to
  #   rebuild real, in-process tools.
  # [tool_runtime] an optional Riffer::Tools::Runtime to inject (e.g. a
  #   remote runtime for shells). When omitted, the agent uses the configured
  #   default (+Riffer.config.tool_runtime+).
  #
  # Raises Riffer::Agent::Serializer::VersionError on an unsupported
  # +schema_version+, and Riffer::ArgumentError on a malformed dict.
  #
  #--
  #: (Hash[Symbol, untyped], context: Hash[Symbol, untyped]?, ?tool_resolver: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool), ?tool_runtime: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> Riffer::Agent
  def from_h(hash, context:, tool_resolver: DEFAULT_TOOL_RESOLVER, tool_runtime: nil)
    # Version -> decoder dispatch. Adding a +when 2+ arm (a back-compat
    # decoder) is how a future breaking change keeps older dicts readable.
    case hash[:schema_version]
    when SCHEMA_VERSION
      decode_v1(hash, context: context, tool_resolver: tool_resolver, tool_runtime: tool_runtime)
    else
      raise VersionError, "Unsupported schema_version: #{hash[:schema_version].inspect} (this Riffer supports #{SCHEMA_VERSION})"
    end
  end

  # Snapshots a resolved agent to a JSON string. Convenience over
  # <tt>JSON.generate(to_h(agent:))</tt>.
  #
  #--
  #: (agent: Riffer::Agent) -> String
  def to_json(agent:)
    JSON.generate(to_h(agent: agent))
  end

  # Reconstructs a runnable agent from a JSON string produced by +to_json+.
  # Handles the JSON parse (with symbol keys) so callers don't have to. See
  # +from_h+ for the arguments.
  #
  #--
  #: (String, context: Hash[Symbol, untyped]?, ?tool_resolver: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool), ?tool_runtime: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> Riffer::Agent
  def from_json(json, context:, tool_resolver: DEFAULT_TOOL_RESOLVER, tool_runtime: nil)
    from_h(JSON.parse(json, symbolize_names: true), context: context, tool_resolver: tool_resolver, tool_runtime: tool_runtime)
  end

  private

  #--
  #: (Hash[Symbol, untyped], context: Hash[Symbol, untyped]?, tool_resolver: ^(Hash[Symbol, untyped]) -> singleton(Riffer::Tool), tool_runtime: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)?) -> Riffer::Agent
  def decode_v1(hash, context:, tool_resolver:, tool_runtime:)
    tools = Array(hash[:tools]).map { |descriptor| tool_resolver.call(descriptor) }

    config_args = {
      identifier: hash[:identifier],
      model: hash[:model],
      instructions: hash[:instructions],
      provider_options: hash[:provider_options] || {},
      model_options: hash[:model_options] || {},
      structured_output: decode_structured_output(hash[:structured_output]),
      max_steps: decode_max_steps(hash),
      tools_config: tools
    } #: Hash[Symbol, untyped]
    # tool_runtime= rejects nil, so only inject when supplied; otherwise the
    # Config default (Riffer.config.tool_runtime) applies.
    config_args[:tool_runtime] = tool_runtime if tool_runtime

    Riffer::Agent.new(config: Riffer::Agent::Config.new(**config_args), context: context)
  end

  #--
  #: (Hash[Symbol, untyped]?) -> Riffer::Params?
  def decode_structured_output(schema)
    return nil if schema.nil?
    Riffer::Params.from_json_schema(schema)
  end

  # +max_steps+ is an agent-level concept: +nil+ means unlimited and rides
  # the wire as JSON +null+, so the value passes straight through. Only an
  # absent key needs a fallback — a partial dict must not silently turn into
  # an unbounded loop.
  #--
  #: (Hash[Symbol, untyped]) -> Numeric?
  def decode_max_steps(hash)
    hash.key?(:max_steps) ? hash[:max_steps] : Riffer::Agent::Config::DEFAULT_MAX_STEPS
  end

  #--
  #: (singleton(Riffer::Tool)) -> Hash[Symbol, untyped]
  def tool_descriptor(tool_class)
    tool_class.to_tool_schema(strict: false).merge(timeout: tool_class.timeout)
  end

  # Builds an anonymous, body-less Riffer::Tool subclass that advertises the
  # descriptor's schema to the LLM. Its +#call+ raises — a shell only has
  # identity, not behavior; route its calls through a remote runtime.
  #
  # Returns +untyped+: steep can't see that +Class.new(Riffer::Tool)+ is a
  # +singleton(Riffer::Tool)+ (cf. Riffer::Mcp::ToolFactory#build_tool_class).
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

      define_method(:call) do |context:, **kwargs|
        raise Riffer::Error,
          "#{self.class.name || "wire tool shell"} '#{self.class.identifier}' has no body; " \
          "route its calls through a remote Riffer::Tools::Runtime (see Riffer::Agent::Serializer)"
      end
      # steep:ignore:end
    end
  end
end
