# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Tools::Runtime::Fibers < Riffer::Tools::Runtime
  #--
  #: (?max_concurrency: Integer?) -> void
  def initialize(max_concurrency: nil)
    super(runner: Riffer::Runner::Fibers.new(max_concurrency: max_concurrency))
  end
end
