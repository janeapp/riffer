# frozen_string_literal: true
# rbs_inline: enabled

# Configuration for the Riffer framework.
class Riffer::Config
  AmazonBedrock = Struct.new(:api_token, :region, :client)
  Anthropic = Struct.new(:api_key, :client)
  AzureOpenAI = Struct.new(:api_key, :endpoint, :client)
  Gemini = Struct.new(:api_key, :client)
  OpenAI = Struct.new(:api_key, :base_url, :client)
  OpenRouter = Struct.new(:api_key, :client)
  Evals = Struct.new(:judge_model)
  Mcp = Struct.new(:credentials, :discovery_runner)

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
      unless value.is_a?(Class) && value < Riffer::Tool
        raise Riffer::ArgumentError,
              "default_activate_tool must be a Riffer::Tool subclass"
      end

      @default_activate_tool = value
    end

    # Sets the default skills backend. Raises Riffer::ArgumentError on an
    # invalid value.
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

  # Tracing-related global configuration.
  class Tracing
    # Whether riffer emits OTEL spans; defaults to +true+, a no-op until a
    # host wires an OTEL SDK.
    attr_reader :enabled #: bool

    # Whether LLM-call spans capture full message content
    # (<tt>gen_ai.input.messages</tt>, <tt>gen_ai.output.messages</tt>,
    # <tt>gen_ai.system_instructions</tt>); defaults to +false+ — message
    # content routinely carries sensitive data.
    attr_reader :capture_messages #: bool

    # The backend riffer routes spans through; defaults to +nil+, a no-op.
    # Riffer auto-detects no backend; assigning one is opt-in.
    attr_reader :backend #: untyped

    #--
    #: () -> void
    def initialize
      @enabled = true
      @capture_messages = false
      @backend = nil
    end

    # Sets the enabled flag, coercing boolean-ish values so an env-var
    # +"false"+ (truthy in Ruby) doesn't silently keep tracing on. Raises
    # Riffer::ArgumentError on an unrecognized value.
    #--
    #: (untyped) -> void
    def enabled=(value)
      @enabled = Riffer::Helpers::Boolean.coerce(value, attribute: "enabled")
    end

    # Sets the capture_messages flag, coercing boolean-ish values so an
    # env-var +"false"+ (truthy in Ruby) doesn't silently enable content
    # capture. Raises Riffer::ArgumentError on an unrecognized value.
    #--
    #: (untyped) -> void
    def capture_messages=(value)
      @capture_messages = Riffer::Helpers::Boolean.coerce(value, attribute: "capture_messages")
    end

    # Sets the tracing backend riffer routes spans through. Raises
    # Riffer::ArgumentError unless the value is +nil+ or responds to the full
    # delegated contract: +in_span+, +current_context+, and +with_context+.
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

  # File-attachment-download policy for +Riffer::Messages::FilePart+ URL sources
  class Files
    # Allow file attachments to be downloaded to send to providers.
    attr_reader :allow_downloads #: bool
    # Maximum file size to download before failing.
    attr_reader :max_bytes #: Integer
    # Maximum amount of time to spend downloading a file before failing.
    attr_reader :timeout #: Integer
    # Maximum number of files to include in an individual message.
    attr_reader :max_per_message #: Integer?
    # Execution pattern for downloading files.
    attr_reader :runner #: Riffer::Runner
    # The object used to fetch a URL source's bytes
    attr_reader :downloader #: untyped

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

    # Sets the allow_downloads flag, coercing boolean-ish values so an env-var
    # +"false"+ (truthy in Ruby) doesn't silently enable downloads.  Raises
    # Riffer::ArgumentError on an unrecognized value.
    #--
    #: (untyped) -> void
    def allow_downloads=(value)
      @allow_downloads = Riffer::Helpers::Boolean.coerce(value, attribute: "allow_downloads")
    end

    # Sets max_bytes, provided value is a positive integer.
    # Raises Riffer::ArgumentError if value is not an Integer or less than or equal to 0.
    #--
    #: (untyped) -> void
    def max_bytes=(value)
      raise Riffer::ArgumentError, "max_bytes must be a positive integer" unless value.is_a?(Integer) && value > 0
      @max_bytes = value
    end

    # Sets timeout, provided value is a positive integer.
    # Raises Riffer::ArgumentError if value is not an Integer or is less than or equal to 0.
    #--
    #: (untyped) -> void
    def timeout=(value)
      raise Riffer::ArgumentError, "timeout must be a positive integer" unless value.is_a?(Integer) && value > 0
      @timeout = value
    end

    # Sets max_per_message, provided value is either nil or a positive integer.
    # Raises Riffer::ArgumentError if value is not an Integer or nil, or is less than or equal to 0.
    #--
    #: (untyped) -> void
    def max_per_message=(value)
      if value.is_a?(Integer) && value > 0
        @max_per_message = value
      elsif value.nil?
        @max_per_message = nil
      else
        raise Riffer::ArgumentError, "max_per_message must be a positive integer or nil"
      end
    end

    # Sets the runner used to process file downloads, provided value is a Riffer::Runner.
    # Raises Riffer::ArgumentError if value is not a Riffer::Runner.
    #--
    #: (untyped) -> void
    def runner=(value)
      valid = value.is_a?(Riffer::Runner)
      raise Riffer::ArgumentError, "runner must be a Riffer::Runner instance" unless valid
      @runner = value
    end

    # Sets the object used to download bytes from a URL.
    # Raises Riffer::ArgumentError if value does not respond to +#call+.
    #--
    #: (untyped) -> void
    def downloader=(value)
      raise Riffer::ArgumentError, "downloader must respond to #call" unless value.respond_to?(:call)
      @downloader = value
    end
  end

  # Consumer-configured token pricing, keyed by +provider/model+ id. Riffer
  # ships no price table, so an unconfigured model carries no cost.
  class Pricing
    # @rbs @rates: Hash[String, Riffer::Config::Pricing::Rates]

    # Per-million-token rates for one model's four token buckets. +cache_read+
    # and +cache_write+ fall back to the +input+ rate when unset.
    class Rates
      # Input rate per million tokens.
      attr_reader :input #: Float

      # Output rate per million tokens.
      attr_reader :output #: Float

      # Cache-read rate per million tokens.
      attr_reader :cache_read #: Float?

      # Cache-write rate per million tokens.
      attr_reader :cache_write #: Float?

      #--
      #: (input: Float, output: Float, ?cache_read: Float?, ?cache_write: Float?) -> void
      def initialize(input:, output:, cache_read: nil, cache_write: nil)
        @input = input
        @output = output
        @cache_read = cache_read
        @cache_write = cache_write
      end

      # Returns the cost for the given token counts.
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

    # Registers per-million-token rates for a +provider/model+ id/s. Raises
    # Riffer::ArgumentError on a malformed id or a negative/non-numeric rate.
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

    # Returns the rates registered for a +provider/model+ id.
    #--
    #: (String) -> Riffer::Config::Pricing::Rates?
    def rates_for(model)
      @rates[model]
    end

    # Returns true when no rates are registered.
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
    valid = (value.is_a?(Class) && value < Riffer::Tools::Runtime) ||
            value.is_a?(Riffer::Tools::Runtime) || value.is_a?(Proc)
    unless valid
      raise Riffer::ArgumentError,
            "tool_runtime must be a Riffer::Tools::Runtime subclass, instance, or a Proc"
    end

    @tool_runtime = value
  end

  # Skills-related global configuration.
  attr_reader :skills #: Riffer::Config::Skills

  # Tracing-related global configuration.
  attr_reader :tracing #: Riffer::Config::Tracing

  attr_reader :files #: Riffer::Config::Files

  # Consumer-configured per-model token pricing.
  attr_reader :pricing #: Riffer::Config::Pricing

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
    @files = Files.new
    @pricing = Pricing.new
    @message_id_strategy = :none
    @experimental_history_healing = false
  end
end
