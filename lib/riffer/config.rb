# frozen_string_literal: true
# rbs_inline: enabled

# Configuration for the Riffer framework.
class Riffer::Config
  AmazonBedrock = Struct.new(:api_token, :region, keyword_init: true)
  Anthropic = Struct.new(:api_key, keyword_init: true)
  AzureOpenAI = Struct.new(:api_key, :endpoint, keyword_init: true)
  Gemini = Struct.new(:api_key, :open_timeout, :read_timeout, keyword_init: true)
  OpenAI = Struct.new(:api_key, keyword_init: true)
  OpenRouter = Struct.new(:api_key, keyword_init: true)
  Evals = Struct.new(:judge_model, keyword_init: true)
  Mcp = Struct.new(:credentials, :discovery_runner, keyword_init: true)

  # Skills-related global configuration.
  class Skills
    # The tool class the LLM calls to activate a skill; defaults to
    # <tt>Riffer::Skills::ActivateTool</tt>.
    attr_reader :default_activate_tool #: singleton(Riffer::Tool)

    # Default skills backend for agents that declare a +skills+ block without
    # one; defaults to +nil+.
    attr_reader :default_backend #: (Riffer::Skills::Backend | Proc)?

    #--
    #: () -> void
    def initialize
      @default_activate_tool = Riffer::Skills::ActivateTool
      @default_backend = nil
    end

    # Sets the default skill activation tool class. Raises Riffer::ArgumentError
    # on an invalid value.
    #--
    #: (singleton(Riffer::Tool)) -> void
    def default_activate_tool=(value)
      raise Riffer::ArgumentError, "default_activate_tool must be a Riffer::Tool subclass" unless value.is_a?(Class) && value < Riffer::Tool
      @default_activate_tool = value
    end

    # Sets the default skills backend. Raises Riffer::ArgumentError on an
    # invalid value.
    #--
    #: ((Riffer::Skills::Backend | Proc)?) -> void
    def default_backend=(value)
      valid = value.nil? || value.is_a?(Riffer::Skills::Backend) || value.is_a?(Proc)
      raise Riffer::ArgumentError, "default_backend must be a Riffer::Skills::Backend instance, Proc, or nil" unless valid
      @default_backend = value
    end
  end

  # Tracing-related global configuration.
  class Tracing
    # Whether riffer emits OTEL spans; defaults to +true+, a no-op until a
    # host wires an OTEL SDK.
    attr_reader :enabled #: bool

    # Explicit OTEL tracer provider; defaults to +nil+, which resolves the
    # global <tt>OpenTelemetry.tracer_provider</tt> at first span.
    attr_reader :tracer_provider #: untyped

    #--
    #: () -> void
    def initialize
      @enabled = true
      @tracer_provider = nil
    end

    # Sets the enabled flag, coercing boolean-ish values so an env-var
    # +"false"+ (truthy in Ruby) doesn't silently keep tracing on. Raises
    # Riffer::ArgumentError on an unrecognized value.
    #--
    #: (untyped) -> void
    def enabled=(value)
      @enabled = Riffer::Helpers::Boolean.coerce(value, attribute: "enabled")
    end

    # Sets an explicit tracer provider, forcing the OTEL backend. Raises
    # Riffer::ArgumentError when the OpenTelemetry API gem isn't available
    # at a supported version.
    #--
    #: (untyped) -> void
    def tracer_provider=(value)
      if !value.nil? && !Riffer::Tracing::Otel.available?
        raise Riffer::ArgumentError,
          "tracer_provider requires the opentelemetry-api gem (#{Riffer::Tracing::Otel::SUPPORTED_API_VERSIONS})"
      end
      @tracer_provider = value
      Riffer::Tracing.reset!
    end
  end

  VALID_MESSAGE_ID_STRATEGIES = %i[none uuid uuidv7].freeze

  # Amazon Bedrock configuration.
  attr_reader :amazon_bedrock #: Riffer::Config::AmazonBedrock

  # Anthropic configuration.
  attr_reader :anthropic #: Riffer::Config::Anthropic

  # Azure OpenAI configuration.
  attr_reader :azure_openai #: Riffer::Config::AzureOpenAI

  # Google Gemini configuration.
  attr_reader :gemini #: Riffer::Config::Gemini

  # OpenAI configuration.
  attr_reader :openai #: Riffer::Config::OpenAI

  # OpenRouter configuration.
  attr_reader :openrouter #: Riffer::Config::OpenRouter

  # Evals configuration.
  attr_reader :evals #: Riffer::Config::Evals

  # MCP configuration. +credentials+ is an optional Proc returning per-run
  # +tools/call+ headers (or +nil+ to deny); +discovery_runner+ runs tool
  # discovery.
  attr_reader :mcp #: Riffer::Config::Mcp

  # Global tool runtime configuration (experimental); defaults to
  # <tt>Riffer::Tools::Runtime::Inline.new</tt>.
  attr_reader :tool_runtime #: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)

  # Sets the global tool runtime. Raises Riffer::ArgumentError on an invalid
  # value.
  #--
  #: ((singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)) -> void
  def tool_runtime=(value)
    valid = (value.is_a?(Class) && value < Riffer::Tools::Runtime) || value.is_a?(Riffer::Tools::Runtime) || value.is_a?(Proc)
    raise Riffer::ArgumentError, "tool_runtime must be a Riffer::Tools::Runtime subclass, instance, or a Proc" unless valid
    @tool_runtime = value
  end

  # Skills-related global configuration.
  attr_reader :skills #: Riffer::Config::Skills

  # Tracing-related global configuration.
  attr_reader :tracing #: Riffer::Config::Tracing

  # Strategy for auto-generating message ids: +:none+ (default), +:uuid+, or
  # +:uuidv7+. When not +:none+, messages get an +id+ at construction, and
  # seeded messages passed to +Riffer::Agent#generate+ must carry their own.
  attr_reader :message_id_strategy #: Symbol

  # Sets the message id strategy. Raises Riffer::ArgumentError unless the value
  # is +:none+, +:uuid+, or +:uuidv7+.
  #--
  #: (Symbol) -> void
  def message_id_strategy=(value)
    unless VALID_MESSAGE_ID_STRATEGIES.include?(value)
      raise Riffer::ArgumentError,
        "message_id_strategy must be one of #{VALID_MESSAGE_ID_STRATEGIES.inspect}, got #{value.inspect}"
    end
    @message_id_strategy = value
  end

  # Experimental: when +true+, riffer maintains the +tool_use+ ↔ +tool_result+
  # invariant itself — stripping orphaned exchanges and filling interrupted
  # ones. Defaults to +false+; the surface may change without notice.
  attr_reader :experimental_history_healing #: bool

  # Sets the +experimental_history_healing+ flag, coercing boolean-ish values so
  # an env-var +"false"+ (truthy in Ruby) doesn't silently enable healing.
  # Raises Riffer::ArgumentError on an unrecognized value.
  #--
  #: (untyped) -> void
  def experimental_history_healing=(value)
    @experimental_history_healing = Riffer::Helpers::Boolean.coerce(value, attribute: "experimental_history_healing")
  end

  #--
  #: () -> void
  def initialize
    @amazon_bedrock = AmazonBedrock.new
    @anthropic = Anthropic.new
    @azure_openai = AzureOpenAI.new
    @gemini = Gemini.new
    @openai = OpenAI.new
    @openrouter = OpenRouter.new
    @evals = Evals.new
    @mcp = Mcp.new(credentials: nil, discovery_runner: Riffer::Runner::Sequential.new)
    @tool_runtime = Riffer::Tools::Runtime::Inline.new
    @skills = Skills.new
    @tracing = Tracing.new
    @message_id_strategy = :none
    @experimental_history_healing = false
  end
end
