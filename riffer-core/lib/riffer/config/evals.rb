# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config::Evals
  attr_reader :judge_model #: String? # @dynamic judge_model

  #--
  #: () -> void
  def initialize
    @judge_model = nil
  end

  #--
  #: (untyped) -> void
  def judge_model=(value)
    @judge_model = value.nil? ? nil : Riffer::Helpers::Validate.model_id(value, attribute: "judge_model")
  end
end
