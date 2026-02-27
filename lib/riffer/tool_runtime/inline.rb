# frozen_string_literal: true
# rbs_inline: enabled

# Executes tool calls sequentially in the current thread.
#
# This is the default tool runtime used when no runtime is configured.
#
class Riffer::ToolRuntime::Inline < Riffer::ToolRuntime
end
