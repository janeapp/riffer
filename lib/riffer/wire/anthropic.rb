# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Wire::Anthropic
  FINISH_REASONS = {
    "end_turn" => :stop,
    "stop_sequence" => :stop,
    "max_tokens" => :length,
    "tool_use" => :tool_calls,
    "refusal" => :content_filter,
    "model_context_window_exceeded" => :context_window,
    # A paused server-tool turn resumes only by re-sending the response; the
    # agent loop does not do that, so it has no normalized equivalent.
    "pause_turn" => :other,
  }.freeze #: Hash[String, Symbol]

  # Only parts carrying this tag are replayed, so reasoning captured by another
  # adapter, whose signatures the Messages API may not accept, never reaches the
  # request.
  REASONING_FORMAT = "anthropic-messages-v1" #: String
end
