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

  # MCP configuration.
  #
  # +credentials+ is an optional Proc for per-run +tools/call+ headers,
  # +->(manifest:, matched_tags:, context:) { Hash or nil }+: +nil+ at
  # tool-resolution omits that server's tools, +nil+ at tool-call time raises
  # Riffer::Mcp::CredentialsDeniedError. +discovery_runner+ executes tool
  # discovery (default +Runner::Sequential+).
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

  # Strategy for auto-generating message ids: +:none+ (default), +:uuid+
  # (UUIDv4), or +:uuidv7+ (time-ordered). When not +:none+, each message gets
  # an +id+ at construction, and seeded messages passed to
  # +Riffer::Agent#generate+ must carry their own +:id+.
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

  # Experimental: when +true+, riffer keeps the +tool_use+ ↔ +tool_result+
  # invariant intact on its own — stripping orphaned exchanges from seeded
  # history and filling orphaned +tool_use+ on interrupt with a placeholder
  # +Riffer::Messages::Tool+ (+error_type: :interrupted+), whose call_ids
  # surface on +Riffer::Agent::Response#healed_tool_call_ids+. Defaults to
  # +false+; the surface may change without notice.
  attr_reader :experimental_history_healing #: bool

  # Sets the +experimental_history_healing+ flag, coercing common boolean
  # representations so an env-var +"false"+ (truthy in Ruby) doesn't silently
  # enable healing. Accepts +true+/+false+, +"true"+/+"false"+, +1+/+0+,
  # +"1"+/+"0"+, and +nil+ (false). Raises Riffer::ArgumentError otherwise.
  #--
  #: (untyped) -> void
  def experimental_history_healing=(value)
    @experimental_history_healing = case value
    when true, "true", 1, "1" then true
    when false, "false", 0, "0", nil then false
    else
      raise Riffer::ArgumentError,
        "experimental_history_healing must be a boolean (or 'true'/'false'/'1'/'0'/1/0), got #{value.inspect}"
    end
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
    @message_id_strategy = :none
    @experimental_history_healing = false
  end
end
