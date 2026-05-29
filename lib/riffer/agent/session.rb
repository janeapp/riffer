# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Agent::Session owns the conversation handle for an agent: the message
# array, the +on_message+ callback list, and the +tool_use+ ↔ +tool_result+
# invariant that keeps tool calls and their results consistent.
#
# Access via +agent.session+. Sessions are constructed by +Riffer::Agent+
# and live for the lifetime of the agent.
#
#   agent.session.add(msg)                  # append + fire callbacks
#   agent.session.set([msg1, msg2])         # bulk replace (silent)
#   agent.session.unset                     # clear (silent)
#   agent.session.remove(id: "a_1")
#   agent.session.update(id: "a_1", content: "...")
#   agent.session.find { |m| m.id == "a_1" }
#
class Riffer::Agent::Session
  include Enumerable #[Riffer::Messages::Base]

  # The message history.
  attr_reader :messages #: Array[Riffer::Messages::Base]

  #--
  #: (?messages: Array[Riffer::Messages::Base]) -> void
  def initialize(messages: [])
    @messages = messages
    @callbacks = [] #: Array[^(Riffer::Messages::Base) -> void]
  end

  # Registers a callback invoked once per message appended via +#add+.
  #
  # Callbacks do NOT fire for +#set+, +#unset+, +#remove+, or +#update+.
  # Returns +self+ to allow chaining.
  #
  # Raises Riffer::ArgumentError if no block is given.
  #
  #--
  #: () { (Riffer::Messages::Base) -> void } -> self
  def on_message(&block)
    raise Riffer::ArgumentError, "on_message requires a block" unless block_given?
    @callbacks << block
    self
  end

  # Appends +message+ and fires every registered callback once with it.
  #
  # Pass +silent: true+ to skip +on_message+ callbacks — used for
  # non-inference inputs like user messages, which subscribers don't
  # expect to observe through the callback channel. Inference-produced
  # messages (Assistant, Tool) always go through +add+ without +silent+.
  #
  #--
  #: (Riffer::Messages::Base, ?silent: bool) -> Riffer::Messages::Base
  def add(message, silent: false)
    @messages << message
    @callbacks.each { |callback| callback.call(message) } unless silent
    message
  end

  # Replaces the message history wholesale. Does NOT fire +on_message+
  # callbacks; registered callbacks persist across the swap.
  #
  # Used for seeding, guardrail rewrites, and history healing — cases
  # where firing callbacks would double-emit messages that subscribers
  # have already observed (or never produced).
  #
  #--
  #: (Array[Riffer::Messages::Base]) -> self
  def set(messages)
    @messages = messages
    self
  end

  # Clears the session. Does NOT fire +on_message+ callbacks; registered
  # callbacks persist.
  #
  #--
  #: () -> self
  def unset
    @messages = []
    self
  end

  # Removes a message by id. When the target is an assistant message that
  # carries +tool_calls+, every +Riffer::Messages::Tool+ result whose
  # +tool_call_id+ matches one of those calls is removed atomically — keeping
  # the +tool_use+ ↔ +tool_result+ invariant intact.
  #
  # Raises Riffer::ArgumentError when called on a +Riffer::Messages::Tool+
  # message — that would orphan the parent's +tool_use+. Use
  # +#update+ to rewrite a tool result instead.
  #
  # Returns the removed message, or +nil+ when no message has the given id
  # (idempotent).
  #
  #--
  #: (id: String) -> Riffer::Messages::Base?
  def remove(id:)
    idx = @messages.index { |m| m.id == id }
    return nil unless idx

    target = @messages[idx]
    if target.is_a?(Riffer::Messages::Tool)
      raise Riffer::ArgumentError,
        "remove cannot drop a Tool message (would orphan the parent's tool_use); use #update instead"
    end

    if target.is_a?(Riffer::Messages::Assistant) && !target.tool_calls.empty?
      child_ids = target.tool_calls.map(&:call_id)
      @messages.reject! { |m| m.is_a?(Riffer::Messages::Tool) && child_ids.include?(m.tool_call_id) }
      @messages.delete(target)
    else
      @messages.delete_at(idx)
    end
    target
  end

  # Partial in-place update. Looks up a message by either +id:+ or
  # +tool_call_id:+ (exactly one required), constructs a replacement of the
  # same concrete type with +attrs+ overlaid on the existing fields, and
  # swaps it in place.
  #
  # When the target is an assistant message and the update drops one or more
  # entries from +tool_calls+, every +Riffer::Messages::Tool+ result whose
  # +tool_call_id+ matches a dropped call is removed atomically — keeping the
  # +tool_use+ ↔ +tool_result+ invariant intact.
  #
  # Raises Riffer::ArgumentError when neither or both lookup keys are
  # provided, or when no message matches.
  #
  #--
  #: (?id: String?, ?tool_call_id: String?, **untyped) -> Riffer::Messages::Base
  def update(id: nil, tool_call_id: nil, **attrs)
    raise Riffer::ArgumentError, "update requires either id: or tool_call_id:" if id.nil? && tool_call_id.nil?
    raise Riffer::ArgumentError, "update accepts id: or tool_call_id:, not both" if id && tool_call_id

    idx = if id
      @messages.index { |m| m.id == id }
    else
      @messages.index { |m| m.is_a?(Riffer::Messages::Tool) && m.tool_call_id == tool_call_id }
    end

    unless idx
      key = id ? "id #{id.inspect}" : "tool_call_id #{tool_call_id.inspect}"
      raise Riffer::ArgumentError, "no message found for #{key}"
    end

    old = @messages[idx] #: Riffer::Messages::Base
    replacement = rebuild_message(old, attrs)
    @messages[idx] = replacement
    cascade_dropped_tool_calls(old, replacement)
    replacement
  end

  # Returns the call_ids of every +tool_call+ on any assistant message that
  # has no matching +Riffer::Messages::Tool+ result anywhere in history.
  #
  # Zero-cost validation hook for callers that want to check the
  # +tool_use+ ↔ +tool_result+ invariant before mutating or persisting.
  #
  #--
  #: () -> Array[String]
  def orphaned_tool_call_ids
    result_ids = @messages.filter_map { |m| m.tool_call_id if m.is_a?(Riffer::Messages::Tool) }
    @messages.flat_map { |m|
      next [] unless m.is_a?(Riffer::Messages::Assistant)
      m.tool_calls.reject { |tc| result_ids.include?(tc.call_id) }.map(&:call_id)
    }
  end

  # Returns +[assistant, pending_tool_calls]+ for the last assistant message.
  # When there is no assistant message or no pending calls, the second
  # element is an empty array.
  #
  #--
  #: () -> [Riffer::Messages::Assistant?, Array[Riffer::Messages::Assistant::ToolCall]]
  def pending_tool_calls
    last_assistant_idx = @messages.rindex { |m| m.is_a?(Riffer::Messages::Assistant) }
    return [nil, []] unless last_assistant_idx

    assistant = @messages[last_assistant_idx] #: Riffer::Messages::Assistant
    return [assistant, []] if assistant.tool_calls.empty?

    executed_ids = @messages[(last_assistant_idx + 1)..].select { |m|
      m.is_a?(Riffer::Messages::Tool)
    }.map(&:tool_call_id)

    [assistant, assistant.tool_calls.reject { |tc| executed_ids.include?(tc.call_id) }]
  end

  #--
  #: () -> Enumerator[Riffer::Messages::Base, self]
  #: () { (Riffer::Messages::Base) -> void } -> untyped
  def each(&block)
    @messages.each(&block)
  end

  # The number of LLM steps completed in this session, derived from the
  # count of assistant messages. Used by the agent loop to enforce
  # +max_steps+ on resume.
  #
  #--
  #: () -> Integer
  def steps
    @messages.count { |m| m.is_a?(Riffer::Messages::Assistant) }
  end

  # The most recent +Riffer::Messages::Assistant+ in the session, or +nil+
  # when none exists.
  #
  #--
  #: () -> Riffer::Messages::Assistant?
  def final_assistant_message
    # TODO: Replace with rfind when minimum Ruby is 4.0+
    # rubocop:disable Style/ReverseFind
    @messages.reverse_each.find { |m| m.is_a?(Riffer::Messages::Assistant) } #: Riffer::Messages::Assistant?
    # rubocop:enable Style/ReverseFind
  end

  private

  #: (Riffer::Messages::Base, Riffer::Messages::Base) -> void
  def cascade_dropped_tool_calls(old, replacement)
    return unless old.is_a?(Riffer::Messages::Assistant)
    return unless replacement.is_a?(Riffer::Messages::Assistant)

    removed_ids = old.tool_calls.map(&:call_id) - replacement.tool_calls.map(&:call_id)
    return if removed_ids.empty?

    @messages.reject! { |m| m.is_a?(Riffer::Messages::Tool) && removed_ids.include?(m.tool_call_id) }
  end

  #: (Riffer::Messages::Base, Hash[Symbol, untyped]) -> Riffer::Messages::Base
  def rebuild_message(old, attrs)
    case old
    when Riffer::Messages::Assistant
      Riffer::Messages::Assistant.new(
        attrs.fetch(:content, old.content),
        id: attrs.fetch(:id, old.id),
        tool_calls: attrs.fetch(:tool_calls, old.tool_calls),
        token_usage: attrs.fetch(:token_usage, old.token_usage),
        structured_output: attrs.fetch(:structured_output, old.structured_output)
      )
    when Riffer::Messages::Tool
      Riffer::Messages::Tool.new(
        attrs.fetch(:content, old.content),
        tool_call_id: old.tool_call_id,
        name: attrs.fetch(:name, old.name),
        id: attrs.fetch(:id, old.id),
        error: attrs.fetch(:error, old.error),
        error_type: attrs.fetch(:error_type, old.error_type)
      )
    when Riffer::Messages::User
      Riffer::Messages::User.new(
        attrs.fetch(:content, old.content),
        id: attrs.fetch(:id, old.id),
        files: attrs.fetch(:files, old.files)
      )
    else
      old.class.new(
        attrs.fetch(:content, old.content),
        id: attrs.fetch(:id, old.id)
      )
    end
  end
end
