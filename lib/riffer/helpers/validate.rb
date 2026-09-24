# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Helpers::Validate
  extend self

  # The error names the class, not the value, so a misassigned secret never
  # lands in a log.
  #--
  #: (untyped, attribute: String) -> String?
  def optional_string(value, attribute:)
    return value if value.nil? || value.is_a?(String)

    raise Riffer::ArgumentError, "#{attribute} must be a String or nil, got #{value.class}"
  end

  #--
  #: (untyped, attribute: String) -> Integer
  def positive_integer(value, attribute:)
    return value if value.is_a?(Integer) && value.positive?

    raise Riffer::ArgumentError, "#{attribute} must be a positive integer"
  end

  #--
  #: (untyped, attribute: String) -> Riffer::Runner
  def runner(value, attribute:)
    return value if value.is_a?(Riffer::Runner)

    raise Riffer::ArgumentError, "#{attribute} must be a Riffer::Runner instance"
  end

  #--
  #: (untyped, attribute: String) -> String
  def model_id(value, attribute:)
    segments = value.to_s.split("/", 2)
    valid = value.is_a?(String) && segments.length == 2 && segments.none? { |segment| segment.strip.empty? }
    return value if valid

    raise Riffer::ArgumentError, "#{attribute} must be in \"provider/model\" form, got #{value.inspect}"
  end
end
