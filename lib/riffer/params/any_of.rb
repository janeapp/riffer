# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Params::AnyOf
  attr_reader :variants #: Array[Riffer::Params] # @dynamic variants

  #--
  #: () -> void
  def initialize
    @variants = []
  end

  #--
  #: () ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> void
  def variant(&block)
    raise Riffer::ArgumentError, "variant requires a block defining its properties" unless block

    params = Riffer::Params.new
    params.instance_eval(&block)
    @variants << params
  end
end
