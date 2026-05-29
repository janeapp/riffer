# frozen_string_literal: true
# rbs_inline: enabled

# Executes tool calls concurrently using threads.
#
#   class MyAgent < Riffer::Agent
#     tool_runtime Riffer::Tools::Runtime::Threaded
#   end
#
class Riffer::Tools::Runtime::Threaded < Riffer::Tools::Runtime
  DEFAULT_MAX_CONCURRENCY = 5 #: Integer

  # [max_concurrency] maximum number of tool calls to execute simultaneously.
  #
  #--
  #: (?max_concurrency: Integer) -> void
  def initialize(max_concurrency: DEFAULT_MAX_CONCURRENCY)
    super(runner: Riffer::Runner::Threaded.new(max_concurrency: max_concurrency))
  end
end
