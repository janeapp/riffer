# frozen_string_literal: true
# rbs_inline: enabled

# Configuration for the Riffer framework.
#
# Provides configuration options for AI providers and other settings.
#
#   Riffer.config.openai.api_key = "sk-..."
#
#   Riffer.config.amazon_bedrock.region = "us-east-1"
#   Riffer.config.amazon_bedrock.api_token = "..."
#
#   Riffer.config.anthropic.api_key = "sk-ant-..."
#
#   Riffer.config.evals.judge_model = "anthropic/claude-sonnet-4-20250514"
#
class Riffer::Config
  AmazonBedrock = Struct.new(:api_token, :region, keyword_init: true)
  Anthropic = Struct.new(:api_key, keyword_init: true)
  AzureOpenAI = Struct.new(:api_key, :endpoint, keyword_init: true)
  Gemini = Struct.new(:api_key, :open_timeout, :read_timeout, keyword_init: true)
  OpenAI = Struct.new(:api_key, keyword_init: true)
  Evals = Struct.new(:judge_model, keyword_init: true)
  Mcp = Struct.new(:on_pending, :wait_timeout, :credentials, :discovery_thread_factory, keyword_init: true)

  # Skills-related global configuration.
  #
  # See <tt>Riffer.config.skills.default_activate_tool</tt> and
  # <tt>Riffer.config.skills.default_backend</tt>.
  class Skills
    # Default skill activation tool class.
    #
    # The tool class the LLM calls to activate a skill. Defaults to
    # <tt>Riffer::Skills::ActivateTool</tt>. Per-agent override is available
    # via <tt>skills do; activate_tool ...; end</tt>.
    attr_reader :default_activate_tool #: singleton(Riffer::Tool)

    # Default skills backend.
    #
    # Used by agents that declare a +skills+ block without specifying a
    # backend. Accepts a Riffer::Skills::Backend instance or a Proc.
    # Defaults to +nil+ (no global default).
    attr_reader :default_backend #: (Riffer::Skills::Backend | Proc)?

    #--
    #: () -> void
    def initialize
      @default_activate_tool = Riffer::Skills::ActivateTool
      @default_backend = nil
    end

    # Sets the default skill activation tool class.
    #
    # Raises +Riffer::ArgumentError+ if the value is not a Riffer::Tool subclass.
    #
    #--
    #: (singleton(Riffer::Tool)) -> void
    def default_activate_tool=(value)
      raise Riffer::ArgumentError, "default_activate_tool must be a Riffer::Tool subclass" unless value.is_a?(Class) && value < Riffer::Tool
      @default_activate_tool = value
    end

    # Sets the default skills backend.
    #
    # Raises +Riffer::ArgumentError+ if the value is not a
    # Riffer::Skills::Backend instance, a Proc, or +nil+.
    #
    #--
    #: ((Riffer::Skills::Backend | Proc)?) -> void
    def default_backend=(value)
      valid = value.nil? || value.is_a?(Riffer::Skills::Backend) || value.is_a?(Proc)
      raise Riffer::ArgumentError, "default_backend must be a Riffer::Skills::Backend instance, Proc, or nil" unless valid
      @default_backend = value
    end
  end

  VALID_MESSAGE_ID_STRATEGIES = %i[none uuid uuidv7].freeze

  # Amazon Bedrock configuration (Struct with +api_token+ and +region+).
  attr_reader :amazon_bedrock #: Riffer::Config::AmazonBedrock

  # Anthropic configuration (Struct with +api_key+).
  attr_reader :anthropic #: Riffer::Config::Anthropic

  # Azure OpenAI configuration (Struct with +api_key+ and +endpoint+).
  attr_reader :azure_openai #: Riffer::Config::AzureOpenAI

  # Google Gemini configuration (Struct with +api_key+, +open_timeout+, and +read_timeout+).
  attr_reader :gemini #: Riffer::Config::Gemini

  # OpenAI configuration (Struct with +api_key+).
  attr_reader :openai #: Riffer::Config::OpenAI

  # Evals configuration (Struct with +judge_model+).
  attr_reader :evals #: Riffer::Config::Evals

  # MCP configuration (Struct with +on_pending+, +wait_timeout+, +credentials+,
  # +discovery_thread_factory+).
  #
  # +on_pending+ controls agent behaviour when an MCP server has not finished
  # discovery: +:ignore+ (default) skips the server, +:wait+ blocks until ready,
  # +:raise+ raises Riffer::Mcp::NotReadyError.
  #
  # +wait_timeout+ is the maximum seconds to wait when +on_pending: :wait+.
  #
  # +credentials+ is an optional Proc for per-run MCP +tools/call+ HTTP headers.
  # Signature: +->(manifest:, matched_tags:, context:) { Hash or nil }+.
  # +nil+ from the proc at tool-resolution time omits that server's tools; +nil+
  # at tool-call time raises Riffer::Mcp::CredentialsDeniedError.
  attr_reader :mcp #: Riffer::Config::Mcp

  # Global tool runtime configuration (experimental).
  #
  # Accepts a Riffer::ToolRuntime subclass, a Riffer::ToolRuntime instance,
  # or a Proc. Defaults to <tt>Riffer::ToolRuntime::Inline.new</tt>.
  attr_reader :tool_runtime #: (singleton(Riffer::ToolRuntime) | Riffer::ToolRuntime | Proc)

  # Sets the global tool runtime.
  #
  # Raises +Riffer::ArgumentError+ if the value is not a valid runtime
  # (ToolRuntime subclass, ToolRuntime instance, or Proc).
  #
  #--
  #: ((singleton(Riffer::ToolRuntime) | Riffer::ToolRuntime | Proc)) -> void
  def tool_runtime=(value)
    valid = (value.is_a?(Class) && value < Riffer::ToolRuntime) || value.is_a?(Riffer::ToolRuntime) || value.is_a?(Proc)
    raise Riffer::ArgumentError, "tool_runtime must be a Riffer::ToolRuntime subclass, instance, or a Proc" unless valid
    @tool_runtime = value
  end

  # Skills-related global configuration. Returns a Riffer::Config::Skills
  # object — see <tt>Riffer.config.skills.default_activate_tool</tt>.
  attr_reader :skills #: Riffer::Config::Skills

  # Strategy for auto-generating message ids. One of +:none+ (default, no id),
  # +:uuid+ (UUIDv4), or +:uuidv7+ (time-ordered UUIDv7).
  #
  # When set to anything other than +:none+, each +Riffer::Messages::Base+
  # instance gets an +id+ populated at construction time, and seeded messages
  # passed to +Riffer::Agent#generate+ must carry their own +:id+.
  attr_reader :message_id_strategy #: Symbol

  # Sets the message id strategy.
  #
  # Raises +Riffer::ArgumentError+ if the value is not one of
  # +:none+, +:uuid+, or +:uuidv7+.
  #
  #--
  #: (Symbol) -> void
  def message_id_strategy=(value)
    unless VALID_MESSAGE_ID_STRATEGIES.include?(value)
      raise Riffer::ArgumentError,
        "message_id_strategy must be one of #{VALID_MESSAGE_ID_STRATEGIES.inspect}, got #{value.inspect}"
    end
    @message_id_strategy = value
  end

  #--
  #: () -> void
  def initialize
    @amazon_bedrock = AmazonBedrock.new
    @anthropic = Anthropic.new
    @azure_openai = AzureOpenAI.new
    @gemini = Gemini.new
    @openai = OpenAI.new
    @evals = Evals.new
    @mcp = Mcp.new(on_pending: :ignore, wait_timeout: 10, credentials: nil,
      discovery_thread_factory: ->(&block) { Thread.new(&block) })
    @tool_runtime = Riffer::ToolRuntime::Inline.new
    @skills = Skills.new
    @message_id_strategy = :none
  end
end
