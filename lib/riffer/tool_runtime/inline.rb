# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::ToolRuntime::Inline < Riffer::ToolRuntime
  #: () -> void
  def initialize
    super(runner: Riffer::Runner::Sequential.new)
  end
end
