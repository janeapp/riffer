# frozen_string_literal: true
# rbs_inline: enabled

# Registry of a class's named direct subclasses, keyed by identifier. Extend it
# onto a base class to look up subclasses in constant time via +find+ and +all+.
#
#   class Riffer::Tool
#     extend Riffer::Registrable
#   end
#
#   Riffer::Tool.find("weather_tool") # => WeatherTool
#
# @rbs module-self Class
module Riffer::Registrable
  # @rbs @identifier_registry: Hash[String, Class]?

  # Finds a registered subclass by identifier, or +nil+ when none matches.
  # Only *named direct* subclasses are registered: grandchildren are not
  # visible to a grandparent's +find+ (call +find+ on their direct parent
  # instead), anonymous classes are never registered, and duplicate identifiers
  # raise Riffer::DuplicateIdentifierError at first lookup.
  #
  #--
  #: (String | Symbol) -> Class?
  def find(identifier)
    identifier_registry[identifier.to_s]
  end

  # Returns all registered subclasses. Only *named direct* subclasses are
  # registered: grandchildren are not included (call +all+ on their direct
  # parent instead), anonymous classes are never registered, and duplicate
  # identifiers raise Riffer::DuplicateIdentifierError at first lookup.
  #
  #--
  #: () -> Array[Class]
  def all
    identifier_registry.values
  end

  private

  # Ruby invokes +inherited+ with +self+ bound to the direct superclass — the
  # only registry the new subclass joins — so busting self's memo is exactly
  # sufficient.
  #--
  #: (Class) -> void
  def inherited(subclass)
    super
    @identifier_registry = nil
  end

  #--
  #: () -> Hash[String, Class]
  def identifier_registry
    @identifier_registry ||= build_identifier_registry
  end

  #--
  #: () -> Hash[String, Class]
  def build_identifier_registry
    registry = {} #: Hash[String, Class]
    subclasses.each_with_object(registry) do |subclass, acc|
      # Anonymous classes are skipped even with an explicit identifier — the
      # MCP factory and serializer shells synthesize short-lived anonymous
      # classes whose registration would flake with GC timing.
      next if Riffer::Helpers::Identifier.for(subclass).empty?

      candidate = subclass #: untyped
      key = candidate.identifier.to_s
      next if key.strip.empty?

      existing = acc[key]
      if existing
        raise Riffer::DuplicateIdentifierError,
              "Duplicate identifier #{key.inspect} for #{existing} and #{subclass}"
      end

      acc[key] = subclass
    end.freeze
  end
end
