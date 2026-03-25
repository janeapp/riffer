# frozen_string_literal: true
# rbs_inline: enabled

require "yaml"

class Riffer::Skills::Frontmatter
  NAME_PATTERN = /\A[a-z0-9]+(-[a-z0-9]+)*\z/ #: Regexp
  MAX_NAME_LENGTH = 64 #: Integer
  MAX_DESCRIPTION_LENGTH = 1024 #: Integer

  attr_reader :name #: String
  attr_reader :description #: String
  attr_reader :metadata #: Hash[Symbol, untyped]

  #: (String) -> [Riffer::Skills::Frontmatter, String]
  def self.parse(raw)
    yaml, body = split_frontmatter(raw)
    raise Riffer::ArgumentError, "missing YAML frontmatter (expected --- delimiters)" if yaml.empty?
    [new(name: yaml.delete(:name), description: yaml.delete(:description), metadata: yaml), body]
  end

  #: (String) -> Riffer::Skills::Frontmatter
  def self.parse_frontmatter(raw)
    yaml, _ = split_frontmatter(raw)
    raise Riffer::ArgumentError, "missing YAML frontmatter (expected --- delimiters)" if yaml.empty?
    new(name: yaml.delete(:name), description: yaml.delete(:description), metadata: yaml)
  end

  #: (String) -> [Hash[Symbol, untyped], String]
  def self.split_frontmatter(raw)
    parts = raw.split(/^---\s*$/, 3)

    if parts.length >= 3 && parts[0].strip.empty?
      parsed = YAML.safe_load(parts[1])
      raise Riffer::ArgumentError, "frontmatter must be a YAML mapping" unless parsed.nil? || parsed.is_a?(Hash)
      [parsed&.transform_keys(&:to_sym) || {}, parts[2].lstrip]
    else
      [{}, raw]
    end
  end
  private_class_method :split_frontmatter

  #: (name: String, description: String, ?metadata: Hash[Symbol, untyped]) -> void
  def initialize(name:, description:, metadata: {})
    validate_name!(name)
    validate_description!(description)
    @name = name.freeze
    @description = description.freeze
    @metadata = metadata.freeze
  end

  private

  #: (untyped) -> void
  def validate_name!(name)
    raise Riffer::ArgumentError, "name must be a String" unless name.is_a?(String)
    raise Riffer::ArgumentError, "name must be 1-#{MAX_NAME_LENGTH} characters" if name.empty? || name.length > MAX_NAME_LENGTH
    raise Riffer::ArgumentError, "name must match #{NAME_PATTERN.source}" unless NAME_PATTERN.match?(name)
  end

  #: (untyped) -> void
  def validate_description!(description)
    raise Riffer::ArgumentError, "description must be a String" unless description.is_a?(String)
    raise Riffer::ArgumentError, "description must be 1-#{MAX_DESCRIPTION_LENGTH} characters" if description.empty? || description.length > MAX_DESCRIPTION_LENGTH
  end
end
