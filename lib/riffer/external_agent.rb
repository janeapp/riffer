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
