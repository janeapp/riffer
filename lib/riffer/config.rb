# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config
  AmazonBedrock = Struct.new(:api_token, :region, :client)
  Anthropic = Struct.new(:api_key, :client)
  AzureOpenAI = Struct.new(:api_key, :endpoint, :client)
  ClaudeCode = Struct.new(
    :binary, :auth, :default_model, :cwd, :timeout, :scrub_env,
    :setting_sources, :system_prompt_mode, :session_persistence, :allowed_tools, :client,
  )
  Gemini = Struct.new(:api_key, :client)
  OpenAI = Struct.new(:api_key, :base_url, :client)
  OpenRouter = Struct.new(:api_key, :client)
  Evals = Struct.new(:judge_model)
  Mcp = Struct.new(:credentials, :discovery_runner)

  class Skills
    attr_reader :default_activate_tool #: singleton(Riffer::Tool) # @dynamic default_activate_tool

    attr_reader :default_backend #: (Riffer::Skills::Backend | Proc)? # @dynamic default_backend

    #--
    #: () -> void
    def initialize
      @default_activate_tool = Riffer::Skills::ActivateTool
      @default_backend = nil
    end

    #--
    #: (singleton(Riffer::Tool)) -> void
    def default_activate_tool=(value)
      unless value.is_a?(Class) && value < Riffer::Tool
        raise Riffer::ArgumentError,
              "default_activate_tool must be a Riffer::Tool subclass"
      end

      @default_activate_tool = value
    end

    #--
    #: ((Riffer::Skills::Backend | Proc)?) -> void
    def default_backend=(value)
      valid = value.nil? || value.is_a?(Riffer::Skills::Backend) || value.is_a?(Proc)
      unless valid
        raise Riffer::ArgumentError,
              "default_backend must be a Riffer::Skills::Backend instance, Proc, or nil"
      end

      @default_backend = value
    end
  end

  class Tracing
    attr_reader :enabled #: bool # @dynamic enabled

    attr_reader :capture_messages #: bool # @dynamic capture_messages

    attr_reader :backend #: untyped # @dynamic backend

    #--
    #: () -> void
    def initialize
      # Spans are a no-op until a host wires an OTEL SDK.
      @enabled = true
      # Message content routinely carries sensitive data.
      @capture_messages = false
      @backend = nil
    end

    #--
    #: (untyped) -> void
    def enabled=(value)
      @enabled = Riffer::Helpers::Boolean.coerce(value, attribute: "enabled")
    end

    #--
    #: (untyped) -> void
    def capture_messages=(value)
      @capture_messages = Riffer::Helpers::Boolean.coerce(value, attribute: "capture_messages")
    end

    #--
    #: (untyped) -> void
    def backend=(value)
      contract = %i[in_span current_context with_context]
      unless value.nil? || contract.all? { |method| value.respond_to?(method) }
        raise Riffer::ArgumentError, "tracing backend must respond to #in_span, #current_context, and #with_context"
      end

      @backend = value
      Riffer::Tracing.reset!
    end
  end

  class Files
    attr_reader :allow_downloads #: bool # @dynamic allow_downloads
    attr_reader :max_bytes #: Integer # @dynamic max_bytes
    attr_reader :timeout #: Integer # @dynamic timeout
    attr_reader :max_per_message #: Integer? # @dynamic max_per_message
    attr_reader :runner #: Riffer::Runner # @dynamic runner
    attr_reader :downloader #: untyped # @dynamic downloader

    #--
    #: () -> void
    def initialize
      @allow_downloads = false
      @max_bytes = 3_500_000
      @timeout = 60
      @max_per_message = nil
      @runner = Riffer::Runner::Sequential.new
      @downloader = Riffer::Files::Downloader.new
    end

    #--
    #: (untyped) -> void
    def allow_downloads=(value)
      @allow_downloads = Riffer::Helpers::Boolean.coerce(value, attribute: "allow_downloads")
    end

    #--
    #: (untyped) -> void
    def max_bytes=(value)
      raise Riffer::ArgumentError, "max_bytes must be a positive integer" unless value.is_a?(Integer) && value.positive?

      @max_bytes = value
    end

    #--
    #: (untyped) -> void
    def timeout=(value)
      raise Riffer::ArgumentError, "timeout must be a positive integer" unless value.is_a?(Integer) && value.positive?

      @timeout = value
    end

    #--
    #: (untyped) -> void
    def max_per_message=(value)
      if value.is_a?(Integer) && value.positive?
        @max_per_message = value
      elsif value.nil?
        @max_per_message = nil
      else
        raise Riffer::ArgumentError, "max_per_message must be a positive integer or nil"
      end
    end

    #--
    #: (untyped) -> void
    def runner=(value)
      valid = value.is_a?(Riffer::Runner)
      raise Riffer::ArgumentError, "runner must be a Riffer::Runner instance" unless valid

      @runner = value
    end

    #--
    #: (untyped) -> void
    def downloader=(value)
      raise Riffer::ArgumentError, "downloader must respond to #call" unless value.respond_to?(:call)

      @downloader = value
    end
  end

  class Pricing
    # @rbs @rates: Hash[String, Riffer::Config::Pricing::Rates]

    class Rates
      attr_reader :input #: Float # @dynamic input

      attr_reader :output #: Float # @dynamic output

      attr_reader :cache_read #: Float? # @dynamic cache_read

      attr_reader :cache_write #: Float? # @dynamic cache_write

      #--
      #: (input: Float, output: Float, ?cache_read: Float?, ?cache_write: Float?) -> void
      def initialize(input:, output:, cache_read: nil, cache_write: nil)
        @input = input
        @output = output
        @cache_read = cache_read
        @cache_write = cache_write
      end

      #--
      #: (input_tokens: Integer, output_tokens: Integer, ?cache_read_tokens: Integer?, ?cache_write_tokens: Integer?) -> Float
      def cost_for(input_tokens:, output_tokens:, cache_read_tokens: nil, cache_write_tokens: nil)
        read = cache_read_tokens || 0
        write = cache_write_tokens || 0
        uncached = input_tokens - read - write
        uncached = 0 if uncached.negative?

        per_million = (uncached * input) +
                      (read * (cache_read || input)) +
                      (write * (cache_write || input)) +
                      (output_tokens * output)
        per_million / 1_000_000.0
      end
    end

    #--
    #: () -> void
    def initialize
      @rates = {}
    end

    #--
    #: ((String | Array[String]), input: Numeric, output: Numeric, ?cache_read: Numeric?, ?cache_write: Numeric?) -> void
    def set(models, input:, output:, cache_read: nil, cache_write: nil)
      ids = models.is_a?(Array) ? models : [models]
      raise Riffer::ArgumentError, "at least one model id is required" if ids.empty?

      ids.each { |id| validate_model!(id) }

      rates = Rates.new(
        input: coerce_rate(input, "input"),
        output: coerce_rate(output, "output"),
        cache_read: coerce_optional_rate(cache_read, "cache_read"),
        cache_write: coerce_optional_rate(cache_write, "cache_write"),
      )
      ids.each { |id| @rates[id] = rates }
    end

    #--
    #: (String) -> Riffer::Config::Pricing::Rates?
    def rates_for(model)
      @rates[model]
    end

    #--
    #: () -> bool
    def empty?
      @rates.empty?
    end

    private

    #--
    #: (String) -> void
    def validate_model!(model)
      segments = model.to_s.split("/", 2)
      valid = segments.length == 2 && segments.none? { |segment| segment.strip.empty? }
      return if valid

      raise Riffer::ArgumentError,
            "pricing model id must be in \"provider/model\" form, got #{model.inspect}"
    end

    #--
    #: (untyped, String) -> Float
    def coerce_rate(value, attribute)
      number = value
      float = value.is_a?(Numeric) ? number.to_f : nil #: Float?
      unless float&.finite? && float >= 0
        raise Riffer::ArgumentError,
              "#{attribute} rate must be a non-negative number, got #{value.inspect}"
      end

      float
    end

    #--
    #: (untyped, String) -> Float?
    def coerce_optional_rate(value, attribute)
      return nil if value.nil?

      coerce_rate(value, attribute)
    end
  end

  VALID_MESSAGE_ID_STRATEGIES = %i[none uuid uuidv7].freeze

  attr_reader :amazon_bedrock #: Riffer::Config::AmazonBedrock # @dynamic amazon_bedrock

  attr_reader :anthropic #: Riffer::Config::Anthropic # @dynamic anthropic

  attr_reader :azure_openai #: Riffer::Config::AzureOpenAI # @dynamic azure_openai

  attr_reader :claude_code #: Riffer::Config::ClaudeCode # @dynamic claude_code

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

  # Experimental: riffer maintains the +tool_use+ ↔ +tool_result+ invariant by
  # stripping orphaned exchanges and filling interrupted ones. The surface may
  # change without notice.
  attr_reader :experimental_history_healing #: bool # @dynamic experimental_history_healing

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
    @claude_code = ClaudeCode.new
    @gemini = Gemini.new
    @openai = OpenAI.new
    @openrouter = OpenRouter.new
    @evals = Evals.new
    @mcp = Mcp.new(credentials: nil, discovery_runner: Riffer::Runner::Sequential.new)
    @tool_runtime = Riffer::Tools::Runtime::Inline.new
    @skills = Skills.new
    @tracing = Tracing.new
    @files = Files.new
    @pricing = Pricing.new
    @message_id_strategy = :none
    @experimental_history_healing = false
  end
end
