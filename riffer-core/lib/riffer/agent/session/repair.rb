# frozen_string_literal: true
# rbs_inline: enabled

# Maintains the invariant that every +tool_use+ has a matching +tool_result+
# and every +tool_result+ has a parent +tool_use+.
module Riffer::Agent::Session::Repair
  extend self

  ORPHAN_PLACEHOLDER = lambda { |_tool_call|
    Riffer::Tools::Response.error("Tool call interrupted before completion.", type: :interrupted)
  } #: ^(Riffer::Messages::Assistant::ToolCall) -> Riffer::Tools::Response

  #--
  #: (Array[Riffer::Messages::Base]) -> [Array[Riffer::Messages::Base], Array[String]]
  def fill_orphans(messages)
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

  #--
  #: (Array[Riffer::Messages::Base]) -> Array[Riffer::Messages::Base]
  def prune_orphans(messages)
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
      next [] if idx == resume_boundary # execute_pending_tool_calls still runs these
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
