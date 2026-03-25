# frozen_string_literal: true
# rbs_inline: enabled

require "yaml"

# Immutable value object holding parsed SKILL.md YAML frontmatter.
#
# Required fields per the Agent Skills spec: +name+ and +description+.
# All unrecognized top-level frontmatter keys are merged into +metadata+.
#
#   frontmatter, body = Riffer::Skills::Frontmatter.parse(raw_content)
#
class Riffer::Skills::Frontmatter
  NAME_PATTERN = /\A[a-z0-9]+(-[a-z0-9]+)*\z/ #: Regexp
  MAX_NAME_LENGTH = 64 #: Integer
  MAX_DESCRIPTION_LENGTH = 1024 #: Integer

  # The skill name (1-64 chars, lowercase alphanumeric and hyphens).
  attr_reader :name #: String

  # The skill description (1-1024 chars).
  attr_reader :description #: String

  # Arbitrary key-value metadata from the spec's +metadata+ field
  # and any unrecognized top-level frontmatter keys.
  attr_reader :metadata #: Hash[Symbol, untyped]

  # Parses a raw SKILL.md string into a Frontmatter and body.
  #
  # Splits on YAML front matter delimiters (+---+). Unrecognized
  # top-level keys become +metadata+. Available to custom backends
  # so they don't need to reimplement parsing.
  #
  # Raises Riffer::ArgumentError if frontmatter is invalid.
  #
  #--
  #: (String) -> [Riffer::Skills::Frontmatter, String]
  def self.parse(raw)
    yaml, body = split_frontmatter(raw)
    raise Riffer::ArgumentError, "missing YAML frontmatter (expected --- delimiters)" if yaml.empty?
    [new(name: yaml.delete(:name), description: yaml.delete(:description), metadata: yaml), body]
  end

  # Parses only the frontmatter from a raw SKILL.md string, ignoring the body.
  #
  # Raises Riffer::ArgumentError if frontmatter is invalid.
  #
  #--
  #: (String) -> Riffer::Skills::Frontmatter
  def self.parse_frontmatter(raw)
    yaml, _ = split_frontmatter(raw)
    raise Riffer::ArgumentError, "missing YAML frontmatter (expected --- delimiters)" if yaml.empty?
    new(name: yaml.delete(:name), description: yaml.delete(:description), metadata: yaml)
  end

  #--
  #: (String) -> [Hash[Symbol, untyped], String]
  def self.split_frontmatter(raw) # :nodoc:
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

  # Creates a new Frontmatter.
  #
  # [name] the skill name (must match +[a-z0-9]([a-z0-9-]*[a-z0-9])?+, 1-64 chars).
  # [description] the skill description (1-1024 chars).
  # [metadata] optional metadata hash.
  #
  # Raises Riffer::ArgumentError if name or description is invalid.
  #
  #--
  #: (name: String, description: String, ?metadata: Hash[Symbol, untyped]) -> void
  def initialize(name:, description:, metadata: {})
    validate_name!(name)
    validate_description!(description)
    @name = name.freeze
    @description = description.freeze
    @metadata = metadata.freeze
  end

  private

  #--
  #: (untyped) -> void
  def validate_name!(name)
    raise Riffer::ArgumentError, "name must be a String" unless name.is_a?(String)
    raise Riffer::ArgumentError, "name must be 1-#{MAX_NAME_LENGTH} characters" if name.empty? || name.length > MAX_NAME_LENGTH
    raise Riffer::ArgumentError, "name must match #{NAME_PATTERN.source}" unless NAME_PATTERN.match?(name)
  end

  #--
  #: (untyped) -> void
  def validate_description!(description)
    raise Riffer::ArgumentError, "description must be a String" unless description.is_a?(String)
    raise Riffer::ArgumentError, "description must be 1-#{MAX_DESCRIPTION_LENGTH} characters" if description.empty? || description.length > MAX_DESCRIPTION_LENGTH
  end
end
