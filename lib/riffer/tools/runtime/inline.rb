# frozen_string_literal: true
# rbs_inline: enabled

# Executes tool calls sequentially in the current thread — the default runtime.
class Riffer::Tools::Runtime::Inline < Riffer::Tools::Runtime
  #--
  #: () -> void
  def initialize
    super(runner: Riffer::Runner::Sequential.new)
  end
end
