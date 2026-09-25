# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config::Pricing
  # @rbs @rates: Hash[String, Riffer::Config::Pricing::Rates]

  #--
  #: () -> void
  def initialize
    @rates = {}
  end

  #--
  #: ((String | Array[String]), input: Numeric, output: Numeric, ?cache_read: Numeric?, ?cache_write: Numeric?) -> void
  def set(models, input:, output:, cache_read: nil, cache_write: nil)
    ids = models.is_a?(Array) ? models : [models]
    raise Riffer::ArgumentError, "at least one model id is required" if ids.empty?

    ids.each { |id| Riffer::Helpers::Validate.model_id(id, attribute: "pricing model id") }

    rates = Rates.new(
      input: coerce_rate(input, "input"),
      output: coerce_rate(output, "output"),
      cache_read: coerce_optional_rate(cache_read, "cache_read"),
      cache_write: coerce_optional_rate(cache_write, "cache_write"),
    )
    ids.each { |id| @rates[id] = rates }
  end

  #--
  #: (String) -> Riffer::Config::Pricing::Rates?
  def rates_for(model)
    @rates[model]
  end

  #--
  #: () -> bool
  def empty?
    @rates.empty?
  end

  private

  #--
  #: (untyped, String) -> Float
  def coerce_rate(value, attribute)
    number = value
    float = value.is_a?(Numeric) ? number.to_f : nil #: Float?
    unless float&.finite? && float >= 0
      raise Riffer::ArgumentError,
            "#{attribute} rate must be a non-negative number, got #{value.inspect}"
    end

    float
  end

  #--
  #: (untyped, String) -> Float?
  def coerce_optional_rate(value, attribute)
    return nil if value.nil?

    coerce_rate(value, attribute)
  end
end
