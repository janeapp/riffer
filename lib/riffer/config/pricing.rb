# frozen_string_literal: true
# rbs_inline: enabled

# @deprecated Set pricing in a catalog file instead (see docs/CATALOG.md).
# A catalog entry's pricing wins over rates registered here.
class Riffer::Config::Pricing
  DEPRECATION_MESSAGE = "riffer: config.pricing is deprecated; move rates into a catalog file " \
                        "listed in config.catalog_files (see docs/CATALOG.md)" #: String

  # @rbs @rates: Hash[String, Riffer::Catalog::Rates]
  # @rbs self.@warned: bool

  #--
  #: () -> void
  def initialize
    @rates = {}
  end

  #--
  #: ((String | Array[String]), input: Numeric, output: Numeric, ?cache_read: Numeric?, ?cache_write: Numeric?) -> void
  def set(models, input:, output:, cache_read: nil, cache_write: nil)
    self.class.warn_deprecated

    ids = models.is_a?(Array) ? models : [models]
    raise Riffer::ArgumentError, "at least one model id is required" if ids.empty?

    ids.each { |id| Riffer::Helpers::Validate.model_id(id, attribute: "pricing model id") }

    rates = Riffer::Catalog::Rates.new(input: input, output: output, cache_read: cache_read, cache_write: cache_write)
    ids.each { |id| @rates[id] = rates }
  end

  #--
  #: (String) -> Riffer::Catalog::Rates?
  def rates_for(model)
    @rates[model]
  end

  #--
  #: () -> bool
  def empty?
    @rates.empty?
  end

  # Once per process, so a boot that sets many models logs one line.
  #--
  #: () -> void
  def self.warn_deprecated
    return if @warned

    @warned = true
    Kernel.warn(DEPRECATION_MESSAGE)
  end
end
