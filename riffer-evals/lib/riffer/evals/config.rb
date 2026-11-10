# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Evals::Config
  attr_reader :judge_model #: String? # @dynamic judge_model

  #--
  #: () -> void
  def initialize
    @judge_model = nil
  end

  #--
  #: (untyped) -> void
  def judge_model=(value)
    @judge_model = value.nil? ? nil : validate_model_id(value)
  end

  private

  #--
  #: (untyped) -> String
  def validate_model_id(value)
    segments = value.to_s.split("/", 2)
    valid = value.is_a?(String) && segments.length == 2 && segments.none? { |segment| segment.strip.empty? }
    return value if valid

    raise Riffer::ArgumentError, "judge_model must be in \"provider/model\" form, got #{value.inspect}"
  end
end
