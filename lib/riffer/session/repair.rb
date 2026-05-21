# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Session::Repair holds the pure transformations that keep the
# +tool_use+ ↔ +tool_result+ invariant on a message array. No state, no
# instance — module-level functions only. Each entry point is gated by
# +Riffer.config.experimental_history_healing+: when the flag is off the
# function returns its input unchanged.
#
# Two seams:
#
# - +fill_orphans+ — fills orphan +tool_use+ blocks with placeholder
#   results. Used on interrupt (caller-issued or +max_steps+).
# - +prune_orphans+ — drops orphan +tool_use+ blocks and parentless Tool
#   messages from a caller-provided seed so it is well-formed before the
#   next inference call. Used at construction time when
#   +Riffer::Agent.new(session:)+ receives a session.
module Riffer::Session::Repair
  # Placeholder used to fill orphan +tool_use+ blocks. Emitted as the
  # +Riffer::Tools::Response+ body for each filled call_id.
  ORPHAN_PLACEHOLDER = ->(_tool_call) {
    Riffer::Tools::Response.error("Tool call interrupted before completion.", type: :interrupted)
  } #: ^(Riffer::Messages::Assistant::ToolCall) -> Riffer::Tools::Response

  # Fills any orphaned +tool_use+ in +messages+ with the
  # +ORPHAN_PLACEHOLDER+ response. Each placeholder Tool message is
  # inserted immediately after its parent assistant message. Returns
  # +[new_messages, filled_call_ids]+; +filled_call_ids+ is empty when
  # there are no orphans.
  #
  # No-op when +Riffer.config.experimental_history_healing+ is off:
  # returns +[messages, []]+ with the same array reference.
  #
  #--
  #: (Array[Riffer::Messages::Base]) -> [Array[Riffer::Messages::Base], Array[String]]
  def self.fill_orphans(messages)
    return [messages, []] unless Riffer.config.experimental_history_healing

    result_ids = messages.filter_map { |m| m.tool_call_id if m.is_a?(Riffer::Messages::Tool) }
    filled = [] #: Array[String]
    new_messages = [] #: Array[Riffer::Messages::Base]

    messages.each do |m|
      new_messages << m
      next unless m.is_a?(Riffer::Messages::Assistant) && !m.tool_calls.empty?

      m.tool_calls.each do |tc|
        next if result_ids.include?(tc.call_id)

        response = ORPHAN_PLACEHOLDER.call(tc)
        new_messages << Riffer::Messages::Tool.new(
          response.content,
          tool_call_id: tc.call_id,
          name: tc.name,
          error: response.error_message,
          error_type: response.error_type
        )
        filled << tc.call_id
      end
    end

    [new_messages, filled]
  end

  # Prunes a seeded message array so the +tool_use+ ↔ +tool_result+
  # invariant holds. Drops orphaned tool exchanges (assistant +tool_call+
  # with no matching Tool result) and parentless Tool messages. Returns a
  # new array; the input is not mutated.
  #
  # Pending tool_calls on the resume boundary — the last assistant whose
  # tail is purely Tool results (or empty) — are preserved. They get
  # swept up by +execute_pending_tool_calls+ at the start of the next
  # generate/stream call.
  #
  # No-op when +Riffer.config.experimental_history_healing+ is off:
  # returns +messages+ unchanged.
  #
  #--
  #: (Array[Riffer::Messages::Base]) -> Array[Riffer::Messages::Base]
  def self.prune_orphans(messages)
    return messages unless Riffer.config.experimental_history_healing

    resume_boundary = (messages.length - 1).downto(0).find { |idx|
      m = messages[idx]
      m.is_a?(Riffer::Messages::Assistant) &&
        messages[(idx + 1)..].all? { |later| later.is_a?(Riffer::Messages::Tool) }
    }

    result_ids = messages.filter_map { |m| m.tool_call_id if m.is_a?(Riffer::Messages::Tool) }
    parent_ids = messages.flat_map { |m|
      m.is_a?(Riffer::Messages::Assistant) ? m.tool_calls.map(&:call_id) : []
    }

    strip_offenders = messages.each_with_index.flat_map { |m, idx|
      next [] unless m.is_a?(Riffer::Messages::Assistant) && !m.tool_calls.empty?
      next [] if idx == resume_boundary # preserve pending exchange
      next [] if m.tool_calls.all? { |tc| result_ids.include?(tc.call_id) }
      m.tool_calls.map(&:call_id)
    }

    messages.reject { |m|
      case m
      when Riffer::Messages::Assistant
        !m.tool_calls.empty? && m.tool_calls.any? { |tc| strip_offenders.include?(tc.call_id) }
      when Riffer::Messages::Tool
        strip_offenders.include?(m.tool_call_id) || !parent_ids.include?(m.tool_call_id)
      else
        false
      end
    }
  end
end
