# frozen_string_literal: true
# rbs_inline: enabled

require "yaml"

# Immutable value object holding parsed SKILL.md YAML frontmatter. Required
# fields: +name+ and +description+; the optional +disable-model-invocation+
# flag is recognized, and any other unrecognized top-level keys are merged into
# +metadata+.
class Riffer::Skills::Frontmatter
  NAME_PATTERN = /\A[a-z0-9]+(-[a-z0-9]+)*\z/ #: Regexp
  MAX_NAME_LENGTH = 64 #: Integer
  MAX_DESCRIPTION_LENGTH = 1024 #: Integer

  # The skill name (1-64 chars, lowercase alphanumeric and hyphens).
  attr_reader :name #: String

  # The skill description (1-1024 chars).
  attr_reader :description #: String

  # Whether the skill opts out of model-driven activation. Hidden from the
  # catalog and rejected at model activation; still reachable via programmatic
  # activation.
  attr_reader :disable_model_invocation #: bool

  # Metadata from the spec's +metadata+ field plus any unrecognized top-level
  # keys.
  attr_reader :metadata #: Hash[Symbol, untyped]

  # Parses a raw SKILL.md string into a +[Frontmatter, body]+ pair — public so
  # custom backends needn't reimplement parsing. Raises Riffer::ArgumentError
  # if the frontmatter is invalid.
  #--
  #: (String) -> [Riffer::Skills::Frontmatter, String]
  def self.parse(raw)
    yaml, body = split_frontmatter(raw)
    raise Riffer::ArgumentError, "missing YAML frontmatter (expected --- delimiters)" if yaml.empty?

    [
      new(name: yaml.delete(:name), description: yaml.delete(:description),
          disable_model_invocation: yaml.delete(:"disable-model-invocation"), metadata: yaml,), body,
    ]
  end

  # Parses only the frontmatter from a raw SKILL.md string, ignoring the body.
  # Raises Riffer::ArgumentError if the frontmatter is invalid.
  #--
  #: (String) -> Riffer::Skills::Frontmatter
  def self.parse_frontmatter(raw)
    yaml, = split_frontmatter(raw)
    raise Riffer::ArgumentError, "missing YAML frontmatter (expected --- delimiters)" if yaml.empty?

    new(name: yaml.delete(:name), description: yaml.delete(:description),
        disable_model_invocation: yaml.delete(:"disable-model-invocation"), metadata: yaml,)
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

  # Raises Riffer::ArgumentError if +name+ or +description+ is invalid.
  # +disable_model_invocation+ is treated as set only when literally +true+.
  #--
  #: (name: String, description: String, ?disable_model_invocation: bool, ?metadata: Hash[Symbol, untyped]) -> void
  def initialize(name:, description:, disable_model_invocation: false, metadata: {})
    validate_name!(name)
    validate_description!(description)
    @name = name.freeze
    @description = description.freeze
    @disable_model_invocation = (disable_model_invocation == true)
    @metadata = metadata.freeze
  end

  private

  #--
  #: (untyped) -> void
  def validate_name!(name)
    raise Riffer::ArgumentError, "name must be a String" unless name.is_a?(String)
    if name.empty? || name.length > MAX_NAME_LENGTH
      raise Riffer::ArgumentError,
            "name must be 1-#{MAX_NAME_LENGTH} characters"
    end
    raise Riffer::ArgumentError, "name must match #{NAME_PATTERN.source}" unless NAME_PATTERN.match?(name)
  end

  #--
  #: (untyped) -> void
  def validate_description!(description)
    raise Riffer::ArgumentError, "description must be a String" unless description.is_a?(String)
    return unless description.empty? || description.length > MAX_DESCRIPTION_LENGTH

    raise Riffer::ArgumentError,
          "description must be 1-#{MAX_DESCRIPTION_LENGTH} characters"
  end
end
