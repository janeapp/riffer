# frozen_string_literal: true
# rbs_inline: enabled

# Executes agent calls sequentially in the current thread.
#
# This is the default agent runtime used when no runtime is configured.
#
class Riffer::AgentRuntime::Inline < Riffer::AgentRuntime
  #--
  #: () -> void
  def initialize
    super(runner: Riffer::Runner::Sequential.new)
  end
end
