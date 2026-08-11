# frozen_string_literal: true
# rbs_inline: enabled

# Pure, stateless transformations keeping the +tool_use+ ↔ +tool_result+
# invariant on a message array. Each entry point no-ops when
# +Riffer.config.experimental_history_healing+ is off.
module Riffer::Agent::Session::Repair
  extend self

  # Placeholder response filled in for an orphaned +tool_use+ on interrupt.
  ORPHAN_PLACEHOLDER = lambda { |_tool_call|
    Riffer::Tools::Response.error("Tool call interrupted before completion.", type: :interrupted)
  } #: ^(Riffer::Messages::Assistant::ToolCall) -> Riffer::Tools::Response

  # Fills each orphaned +tool_use+ in +messages+ with an +ORPHAN_PLACEHOLDER+
  # result inserted after its parent. Returns +[new_messages, filled_call_ids]+.
  #--
  #: (Array[Riffer::Messages::Base]) -> [Array[Riffer::Messages::Base], Array[String]]
  def fill_orphans(messages)
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
          error_type: response.error_type,
        )
        filled << tc.call_id
      end
    end

    [new_messages, filled]
  end

  # Prunes a seeded message array to the invariant — dropping orphaned tool
  # exchanges and parentless Tool messages, but preserving the pending
  # tool_calls on the resume boundary (the last assistant) for
  # +execute_pending_tool_calls+. Returns a new array.
  #--
  #: (Array[Riffer::Messages::Base]) -> Array[Riffer::Messages::Base]
  def prune_orphans(messages)
    return messages unless Riffer.config.experimental_history_healing

    resume_boundary = (messages.length - 1).downto(0).find do |idx|
      m = messages[idx]
      m.is_a?(Riffer::Messages::Assistant) &&
        (messages[(idx + 1)..] || []).all?(Riffer::Messages::Tool)
    end

    result_ids = messages.filter_map { |m| m.tool_call_id if m.is_a?(Riffer::Messages::Tool) }
    parent_ids = messages.flat_map do |m|
      m.is_a?(Riffer::Messages::Assistant) ? m.tool_calls.map(&:call_id) : []
    end

    strip_offenders = messages.each_with_index.flat_map do |m, idx|
      next [] unless m.is_a?(Riffer::Messages::Assistant) && !m.tool_calls.empty?
      next [] if idx == resume_boundary # preserve pending exchange
      next [] if m.tool_calls.all? { |tc| result_ids.include?(tc.call_id) }

      m.tool_calls.map(&:call_id)
    end

    messages.reject do |m|
      case m
      when Riffer::Messages::Assistant
        !m.tool_calls.empty? && m.tool_calls.any? { |tc| strip_offenders.include?(tc.call_id) }
      when Riffer::Messages::Tool
        strip_offenders.include?(m.tool_call_id) || !parent_ids.include?(m.tool_call_id)
      else
        false
      end
    end
  end
end
