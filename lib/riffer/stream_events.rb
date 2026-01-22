# frozen_string_literal: true

# Namespace for streaming event types in the Riffer framework.
#
# When streaming responses, these events are yielded to represent incremental updates:
# - Riffer::StreamEvents::TextDelta - Incremental text content
# - Riffer::StreamEvents::TextDone - Complete text content
# - Riffer::StreamEvents::ToolCallDelta - Incremental tool call arguments
# - Riffer::StreamEvents::ToolCallDone - Complete tool call
# - Riffer::StreamEvents::ReasoningDelta - Incremental reasoning content
# - Riffer::StreamEvents::ReasoningDone - Complete reasoning content
module Riffer::StreamEvents
end
