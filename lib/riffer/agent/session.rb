# frozen_string_literal: true
# rbs_inline: enabled

# Owns the conversation handle for an agent: the message array, the
# +on_message+ callbacks, and the +tool_use+ ↔ +tool_result+ invariant that
# keeps tool calls and their results consistent.
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

  # @rbs @callbacks: Array[^(Riffer::Messages::Base) -> void]

  # The message history.
  attr_reader :messages #: Array[Riffer::Messages::Base]

  #--
  #: (?messages: Array[Riffer::Messages::Base]) -> void
  def initialize(messages: [])
    @messages = messages
    @callbacks = [] #: Array[^(Riffer::Messages::Base) -> void]
  end

  # Registers a callback invoked once per message appended via +#add+.
  #--
  #: () { (Riffer::Messages::Base) -> void } -> self
  def on_message(&block)
    raise Riffer::ArgumentError, "on_message requires a block" unless block_given?

    @callbacks << block
    self
  end

  # Appends +message+ and fires every registered callback once with it. Pass
  # +silent: true+ to skip callbacks — used for non-inference inputs like user
  # messages that subscribers don't expect on the callback channel.
  #--
  #: (Riffer::Messages::Base, ?silent: bool) -> Riffer::Messages::Base
  def add(message, silent: false)
    @messages << message
    @callbacks.each { |callback| callback.call(message) } unless silent
    message
  end

  # Replaces the message history wholesale
  #--
  #: (Array[Riffer::Messages::Base]) -> self
  def set(messages)
    @messages = messages
    self
  end

  # Clears the session.
  #--
  #: () -> self
  def unset
    @messages = []
    self
  end

  # Removes a message by id, cascading to drop the +Tool+ results of a removed
  # assistant's +tool_calls+ so the +tool_use+ ↔ +tool_result+ invariant holds.
  # Raises on a +Tool+ message — that would orphan its parent; use +#update+
  # instead. Returns +nil+ if no message matches.
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

  # Partial in-place update: looks up a message by +id:+ or +tool_call_id:+
  # (exactly one), overlays +attrs+ onto a same-type replacement, and swaps it
  # in. Dropping +tool_calls+ from an assistant cascades to remove their +Tool+
  # results, preserving the invariant. Raises on neither/both keys or no match.
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

  # Returns the call_ids of every +tool_call+ with no matching
  # +Riffer::Messages::Tool+ result anywhere in history — a hook for checking
  # the +tool_use+ ↔ +tool_result+ invariant before mutating or persisting.
  #--
  #: () -> Array[String]
  def orphaned_tool_call_ids
    result_ids = @messages.filter_map { |m| m.tool_call_id if m.is_a?(Riffer::Messages::Tool) }
    @messages.flat_map do |m|
      next [] unless m.is_a?(Riffer::Messages::Assistant)

      m.tool_calls.reject { |tc| result_ids.include?(tc.call_id) }.map(&:call_id)
    end
  end

  # Returns +[last_assistant, pending_tool_calls]+; the second element is empty
  # when there's no assistant message or no pending calls.
  #--
  #: () -> [Riffer::Messages::Assistant?, Array[Riffer::Messages::Assistant::ToolCall]]
  def pending_tool_calls
    last_assistant_idx = @messages.rindex { |m| m.is_a?(Riffer::Messages::Assistant) }
    return [nil, []] unless last_assistant_idx

    assistant = @messages[last_assistant_idx] #: Riffer::Messages::Assistant
    return [assistant, []] if assistant.tool_calls.empty?

    executed_ids = (@messages[(last_assistant_idx + 1)..] || []).filter_map do |m|
      m.tool_call_id if m.is_a?(Riffer::Messages::Tool)
    end

    [assistant, assistant.tool_calls.reject { |tc| executed_ids.include?(tc.call_id) }]
  end

  # Yields each message in order, or returns an Enumerator without a block.
  #--
  #: () -> Enumerator[Riffer::Messages::Base, self]
  #: () { (Riffer::Messages::Base) -> void } -> untyped
  def each(&block)
    return @messages.each unless block

    @messages.each(&block)
  end

  # The number of LLM steps completed, used by the agent loop to enforce
  # +max_steps+ on resume.
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
    @messages.reverse_each.find { |m| m.is_a?(Riffer::Messages::Assistant) } #: Riffer::Messages::Assistant?
  end

  private

  #--
  #: (Riffer::Messages::Base, Riffer::Messages::Base) -> void
  def cascade_dropped_tool_calls(old, replacement)
    return unless old.is_a?(Riffer::Messages::Assistant)
    return unless replacement.is_a?(Riffer::Messages::Assistant)

    removed_ids = old.tool_calls.map(&:call_id) - replacement.tool_calls.map(&:call_id)
    return if removed_ids.empty?

    @messages.reject! { |m| m.is_a?(Riffer::Messages::Tool) && removed_ids.include?(m.tool_call_id) }
  end

  #--
  #: (Riffer::Messages::Base, Hash[Symbol, untyped]) -> Riffer::Messages::Base
  def rebuild_message(old, attrs)
    case old
    when Riffer::Messages::Assistant
      Riffer::Messages::Assistant.new(
        attrs.fetch(:content, old.content),
        id: attrs.fetch(:id, old.id),
        tool_calls: attrs.fetch(:tool_calls, old.tool_calls),
        token_usage: attrs.fetch(:token_usage, old.token_usage),
        structured_output: attrs.fetch(:structured_output, old.structured_output),
        finish_reason: attrs.fetch(:finish_reason, old.finish_reason),
        finish_reason_raw: attrs.fetch(:finish_reason_raw, old.finish_reason_raw),
      )
    when Riffer::Messages::Tool
      Riffer::Messages::Tool.new(
        attrs.fetch(:content, old.content),
        tool_call_id: old.tool_call_id,
        name: attrs.fetch(:name, old.name),
        id: attrs.fetch(:id, old.id),
        error: attrs.fetch(:error, old.error),
        error_type: attrs.fetch(:error_type, old.error_type),
      )
    when Riffer::Messages::User
      Riffer::Messages::User.new(
        attrs.fetch(:content, old.content),
        id: attrs.fetch(:id, old.id),
        files: attrs.fetch(:files, old.files),
      )
    else
      old.class.new(
        attrs.fetch(:content, old.content),
        id: attrs.fetch(:id, old.id),
      )
    end
  end
end
