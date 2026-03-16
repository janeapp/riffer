# frozen_string_literal: true
# rbs_inline: enabled

# Executes agent calls concurrently using threads.
#
#   class MySupervisor < Riffer::Agent
#     agent_runtime Riffer::AgentRuntime::Threaded
#   end
#
class Riffer::AgentRuntime::Threaded < Riffer::AgentRuntime
  DEFAULT_MAX_CONCURRENCY = 5 #: Integer

  # +max_concurrency+ - maximum number of agent calls to execute simultaneously.
  #
  #: (?max_concurrency: Integer) -> void
  def initialize(max_concurrency: DEFAULT_MAX_CONCURRENCY)
    super(runner: Riffer::Runner::Threaded.new(max_concurrency: max_concurrency))
  end
end
