# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Wire::Anthropic
  # Only parts carrying this tag are replayed, so reasoning captured by another
  # adapter, whose signatures the Messages API may not accept, never reaches the
  # request.
  REASONING_FORMAT = "anthropic-messages-v1" #: String
end
