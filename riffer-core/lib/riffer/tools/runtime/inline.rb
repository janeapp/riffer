# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Tools::Runtime::Inline < Riffer::Tools::Runtime
  #--
  #: () -> void
  def initialize
    super(runner: Riffer::Runner::Sequential.new)
  end
end
