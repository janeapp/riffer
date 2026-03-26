# frozen_string_literal: true
# rbs_inline: enabled

# Executes tool calls concurrently using fibers via the +async+ gem.
#
#   class MyAgent < Riffer::Agent
#     tool_runtime Riffer::ToolRuntime::Fibers
#   end
#
class Riffer::ToolRuntime::Fibers < Riffer::ToolRuntime
  # [max_concurrency] maximum number of tool calls to execute simultaneously.
  #   When +nil+, all tool calls run as fibers without limit.
  #
  #--
  #: (?max_concurrency: Integer?) -> void
  def initialize(max_concurrency: nil)
    super(runner: Riffer::Runner::Fibers.new(max_concurrency: max_concurrency))
  end
end
