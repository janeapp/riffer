# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config
  VALID_MESSAGE_ID_STRATEGIES = %i[none uuid uuidv7].freeze

  attr_reader :amazon_bedrock #: Riffer::Config::AmazonBedrock # @dynamic amazon_bedrock

  attr_reader :anthropic #: Riffer::Config::Anthropic # @dynamic anthropic

  attr_reader :azure_openai #: Riffer::Config::AzureOpenAI # @dynamic azure_openai

  attr_reader :gemini #: Riffer::Config::Gemini # @dynamic gemini

  attr_reader :openai #: Riffer::Config::OpenAI # @dynamic openai

  attr_reader :openrouter #: Riffer::Config::OpenRouter # @dynamic openrouter

  attr_reader :evals #: Riffer::Config::Evals # @dynamic evals

  attr_reader :mcp #: Riffer::Config::Mcp # @dynamic mcp

  attr_reader :tool_runtime #: (singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc) # @dynamic tool_runtime

  #--
  #: ((singleton(Riffer::Tools::Runtime) | Riffer::Tools::Runtime | Proc)) -> void
  def tool_runtime=(value)
    valid = (value.is_a?(Class) && value < Riffer::Tools::Runtime) ||
            value.is_a?(Riffer::Tools::Runtime) || value.is_a?(Proc)
    unless valid
      raise Riffer::ArgumentError,
            "tool_runtime must be a Riffer::Tools::Runtime subclass, instance, or a Proc"
    end

    @tool_runtime = value
  end

  attr_reader :skills #: Riffer::Config::Skills # @dynamic skills

  attr_reader :tracing #: Riffer::Config::Tracing # @dynamic tracing

  attr_reader :files #: Riffer::Config::Files # @dynamic files

  attr_reader :pricing #: Riffer::Config::Pricing # @dynamic pricing

  # When not +:none+, seeded messages passed to +Riffer::Agent#generate+ must
  # carry their own +id+.
  attr_reader :message_id_strategy #: Symbol # @dynamic message_id_strategy

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
    @openrouter = OpenRouter.new
    @evals = Evals.new
    @mcp = Mcp.new
    @tool_runtime = Riffer::Tools::Runtime::Inline.new
    @skills = Skills.new
    @tracing = Tracing.new
    @files = Files.new
    @pricing = Pricing.new
    @message_id_strategy = :none
  end
end
