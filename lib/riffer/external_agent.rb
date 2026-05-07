# frozen_string_literal: true
# rbs_inline: enabled

# Base class for vendor-mediated agent implementations.
#
# Subclass to wrap an external agent (e.g. a CLI binary or vendor SDK) and
# expose it through the standard Riffer agent contract. Subclasses override
# +#generate+, populate +@messages+ via +#record_message+, and accumulate
# token counts via +#accumulate_token_usage+.
#
#   class MyExternalAgent < Riffer::ExternalAgent
#     def generate(prompt_or_messages, files: nil, context: nil)
#       # ... call the vendor ...
#       record_message(Riffer::Messages::User.new(prompt_or_messages))
#       record_message(Riffer::Messages::Assistant.new(reply))
#       accumulate_token_usage(usage_from_vendor)
#       Riffer::ExternalAgent::Response.new(reply, messages: messages.dup, token_usage: token_usage)
#     end
#
#     def extract_telemetry(raw_output)
#       # ... return [Riffer::TokenUsage, Array<Riffer::ExternalAgent::ToolCall>] ...
#     end
#   end
#
# +#generate+ and +#stream+ inherit NotImplementedError bodies from
# Riffer::AgentInterface; subclasses must override at least +#generate+.
class Riffer::ExternalAgent
  include Riffer::AgentInterface

  # Class-level DSL for declaring the agent identifier a subclass runs as.
  #
  # Mirrors the pattern of Riffer::Agent.identifier: call with a string to
  # set, call without arguments to read. Inherits from the superclass when
  # the subclass has not declared its own.
  #
  #   class MyAgent < Riffer::ExternalAgent
  #     agent "my-vendor/1.0"
  #   end
  #   MyAgent.agent  # => "my-vendor/1.0"
  #
  #--
  #: (?String?) -> String?
  def self.agent(identifier_string = nil)
    @agent_identifier = identifier_string unless identifier_string.nil?
    return @agent_identifier if defined?(@agent_identifier) && @agent_identifier
    superclass.respond_to?(:agent) ? superclass.agent : nil
  end

  # Parses a +"vendor/name"+ identifier string into a frozen Identifier.
  #
  # Subclasses override this to add vendor-specific alias resolution
  # (e.g. mapping +"latest"+ to a concrete version). The default
  # implementation validates the +"vendor/name"+ shape and treats
  # +raw+ and +resolved+ as identical.
  #
  # Raises Riffer::ArgumentError when the string is missing a slash or
  # has empty halves.
  #
  #--
  #: (String) -> Riffer::ExternalAgent::Identifier
  def self.parse_identifier(identifier_string)
    parts = identifier_string.to_s.split("/", 2)
    unless parts.size == 2 && parts.none? { |p| p.empty? }
      raise Riffer::ArgumentError,
        "agent identifier must be 'vendor/name', got: #{identifier_string.inspect}"
    end
    Riffer::ExternalAgent::Identifier.new(vendor: parts[0], raw: parts[1], resolved: parts[1])
  end

  # The accumulated message history for this agent instance.
  attr_reader :messages #: Array[Riffer::Messages::Base]

  # The cumulative token usage across all generate calls.
  attr_reader :token_usage #: Riffer::TokenUsage?

  # [context] optional context hash forwarded to subclass-level concerns.
  #
  #--
  #: (?context: Hash[Symbol, untyped]?) -> void
  def initialize(context: nil)
    @context = context
    @messages = []
    @token_usage = nil
    @message_callbacks = []
  end

  # Registers a callback invoked when +#record_message+ appends a message.
  #
  # The block receives each Riffer::Messages::Base instance as it is added.
  # Returns self so registrations can be chained.
  #
  #--
  #: () { (Riffer::Messages::Base) -> void } -> self
  def on_message(&block)
    raise Riffer::ArgumentError, "on_message requires a block" unless block_given?
    @message_callbacks << block
    self
  end

  # Subclass hook for normalizing vendor output into Riffer types.
  #
  # Implementations should return a tuple of the call's token usage and any
  # tool calls observed in the vendor output:
  #
  #   [Riffer::TokenUsage, Array<Riffer::ExternalAgent::ToolCall>]
  #
  # The base class never invokes this method itself; it exists as a
  # documented seam so subclasses can keep their parsing logic separate
  # from response construction.
  #
  #--
  #: (untyped) -> [Riffer::TokenUsage, Array[Riffer::ExternalAgent::ToolCall]]
  def extract_telemetry(raw_output)
    raise NotImplementedError, "#{self.class}#extract_telemetry is not implemented"
  end

  protected

  # Appends a message to +#messages+ and fires every registered on_message callback.
  #
  #--
  #: (Riffer::Messages::Base) -> void
  def record_message(message)
    @messages << message
    @message_callbacks.each { |cb| cb.call(message) }
  end

  # Adds the given usage to the running +#token_usage+ total.
  #
  # Sets +@token_usage+ on the first call; subsequent calls combine via
  # Riffer::TokenUsage#+ to keep cache token semantics correct.
  #
  #--
  #: (Riffer::TokenUsage) -> Riffer::TokenUsage
  def accumulate_token_usage(usage)
    @token_usage = @token_usage ? @token_usage + usage : usage
  end
end
