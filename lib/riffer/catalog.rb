# frozen_string_literal: true
# rbs_inline: enabled

require "json"

class Riffer::Catalog
  SUPPORTED_VERSIONS = [1].freeze #: Array[Integer]

  FILE_KEYS = %w[version models].freeze #: Array[String]

  ENTRY_KEYS = %w[aliases pricing reasoning].freeze #: Array[String]

  PRICING_KEYS = %w[input output cache_read cache_write].freeze #: Array[String]

  # @rbs @models: Hash[String, Hash[Symbol, untyped]]
  # @rbs @aliases: Hash[String, String]

  #--
  #: (Array[String]) -> Riffer::Catalog
  def self.load(paths)
    models = {} #: Hash[String, Hash[Symbol, untyped]]
    aliases = {} #: Hash[String, String]

    paths.each do |path|
      parse_file(path).each do |key, entry|
        layered = models[key] || { aliases: [] }
        layered = layered.merge(entry.slice(:pricing, :reasoning))
        layered[:aliases] = layered[:aliases] | entry[:aliases]
        models[key] = layered

        # A later file wins a claimed alias, so a user file can repoint one.
        entry[:aliases].each do |alias_key|
          previous = aliases[alias_key]
          previous_entry = models[previous] if previous && previous != key
          previous_entry[:aliases] -= [alias_key] if previous_entry
          aliases[alias_key] = key
        end
      end
    end

    aliases.each do |alias_key, key|
      next unless models.key?(alias_key)

      raise Riffer::ArgumentError, "catalog alias #{alias_key.inspect} on #{key.inspect} is also a model key"
    end

    new(models: models, aliases: aliases)
  end

  #--
  #: (models: Hash[String, Hash[Symbol, untyped]], aliases: Hash[String, String]) -> void
  def initialize(models:, aliases:)
    @models = deep_freeze(models)
    @aliases = aliases.dup.freeze
    freeze
  end

  #--
  #: (String, Symbol) -> Hash[Symbol, untyped]?
  def reasoning_options(key, level)
    entry(key)&.dig(:reasoning, level)
  end

  #--
  #: (String) -> Riffer::Catalog::Rates?
  def rates_for(key)
    entry(key)&.dig(:pricing)
  end

  #--
  #: () -> bool
  def empty?
    @models.empty?
  end

  #--
  #: (String) -> Hash[String, Hash[Symbol, untyped]]
  def self.parse_file(path)
    data = begin
      JSON.parse(File.read(path))
    rescue JSON::ParserError, SystemCallError => e
      raise Riffer::ArgumentError, "#{path}: cannot load catalog file (#{e.message})"
    end

    fail_load!(path, "must be a JSON object") unless data.is_a?(Hash)
    unknown = data.keys - FILE_KEYS
    fail_load!(path, "unknown keys #{unknown.inspect}; allowed: #{FILE_KEYS.inspect}") unless unknown.empty?
    unless SUPPORTED_VERSIONS.include?(data["version"])
      fail_load!(path, "unsupported version #{data['version'].inspect}; supported: #{SUPPORTED_VERSIONS.inspect}")
    end

    no_models = {} #: Hash[String, untyped]
    models = data.fetch("models", no_models)
    fail_load!(path, "models must be an object") unless models.is_a?(Hash)

    claimed = {} #: Hash[String, String]
    models.to_h do |key, raw|
      entry = parse_entry(path, key, raw)
      entry[:aliases].each do |alias_key|
        if claimed.key?(alias_key)
          fail_load!(path,
                     "alias #{alias_key.inspect} is listed by both #{claimed[alias_key].inspect} and #{key.inspect}",)
        end

        claimed[alias_key] = key
      end
      [key, entry]
    end
  end
  private_class_method :parse_file

  #--
  #: (String, String, untyped) -> Hash[Symbol, untyped]
  def self.parse_entry(path, key, raw)
    validate_model_key!(path, key, "model key")
    fail_load!(path, "#{key}: entry must be an object") unless raw.is_a?(Hash)
    unknown = raw.keys - ENTRY_KEYS
    fail_load!(path, "#{key}: unknown keys #{unknown.inspect}; allowed: #{ENTRY_KEYS.inspect}") unless unknown.empty?

    entry = { aliases: parse_aliases(path, key, raw.fetch("aliases", [])) } #: Hash[Symbol, untyped]
    entry[:pricing] = parse_pricing(path, key, raw["pricing"]) if raw.key?("pricing")
    entry[:reasoning] = parse_reasoning(path, key, raw["reasoning"]) if raw.key?("reasoning")
    entry
  end
  private_class_method :parse_entry

  #--
  #: (String, String, untyped) -> Array[String]
  def self.parse_aliases(path, key, raw)
    fail_load!(path, "#{key}: aliases must be an array of strings") unless raw.is_a?(Array)

    raw.each { |alias_key| validate_model_key!(path, alias_key, "#{key}: alias") }
    raw.uniq
  end
  private_class_method :parse_aliases

  #--
  #: (String, String, untyped) -> Riffer::Catalog::Rates
  def self.parse_pricing(path, key, raw)
    fail_load!(path, "#{key}: pricing must be an object") unless raw.is_a?(Hash)
    unknown = raw.keys - PRICING_KEYS
    unless unknown.empty?
      fail_load!(path,
                 "#{key}: unknown pricing keys #{unknown.inspect}; allowed: #{PRICING_KEYS.inspect}",)
    end
    missing = %w[input output] - raw.keys
    fail_load!(path, "#{key}: pricing is missing #{missing.inspect}") unless missing.empty?

    begin
      Riffer::Catalog::Rates.new(
        input: raw["input"],
        output: raw["output"],
        cache_read: raw["cache_read"],
        cache_write: raw["cache_write"],
      )
    rescue Riffer::ArgumentError => e
      fail_load!(path, "#{key}: pricing #{e.message}")
    end
  end
  private_class_method :parse_pricing

  #--
  #: (String, String, untyped) -> Hash[Symbol, Hash[Symbol, untyped]]
  def self.parse_reasoning(path, key, raw)
    fail_load!(path, "#{key}: reasoning must be an object") unless raw.is_a?(Hash)

    levels = Riffer::Agent::Config::REASONING_LEVELS
    raw.to_h do |level, fragment|
      unless levels.include?(level.to_sym)
        fail_load!(path, "#{key}: unknown reasoning level #{level.inspect}; allowed: #{levels.map(&:to_s).inspect}")
      end
      fail_load!(path, "#{key}: reasoning #{level} must be an object") unless fragment.is_a?(Hash)

      # Symbol keys, so a fragment deep-merges with the caller's model_options.
      [level.to_sym, symbolize_keys(fragment)]
    end
  end
  private_class_method :parse_reasoning

  #--
  #: (String, untyped, String) -> void
  def self.validate_model_key!(path, value, attribute)
    Riffer::Helpers::Validate.model_id(value, attribute: attribute)
  rescue Riffer::ArgumentError => e
    fail_load!(path, e.message)
  end
  private_class_method :validate_model_key!

  #--
  #: (untyped) -> untyped
  def self.symbolize_keys(value)
    case value
    when Hash then value.to_h { |key, entry| [key.to_sym, symbolize_keys(entry)] }
    when Array then value.map { |entry| symbolize_keys(entry) }
    else value
    end
  end
  private_class_method :symbolize_keys

  #--
  #: (String, String) -> bot
  def self.fail_load!(path, message)
    raise Riffer::ArgumentError, "#{path}: #{message}"
  end
  private_class_method :fail_load!

  private

  #--
  #: (String) -> Hash[Symbol, untyped]?
  def entry(key)
    target = @aliases.fetch(key, key)
    @models[target]
  end

  #--
  #: (untyped) -> untyped
  def deep_freeze(value)
    case value
    when Hash then value.each_value { |entry| deep_freeze(entry) }
    when Array then value.each { |entry| deep_freeze(entry) }
    end
    value.freeze
  end
end
