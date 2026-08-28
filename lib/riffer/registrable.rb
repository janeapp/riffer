# frozen_string_literal: true
# rbs_inline: enabled

# Registry of a class's direct subclasses, keyed by identifier. Extend it
# onto a base class to look up subclasses in constant time via +find+ and +all+.
# Subclasses join implicitly by inheriting; +register+ adds one explicitly, for
# ephemeral classes a test suite builds and tears down. Registration is not
# synchronized — register during boot or from a single-threaded test, before
# concurrent lookups begin.
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
  # @rbs @explicit_registrations: Hash[String, Class]?

  # Finds a registered subclass by identifier, or +nil+ when none matches.
  # Implicit registration covers only *named direct* subclasses: grandchildren
  # are not visible to a grandparent's +find+ (call +find+ on their direct
  # parent instead), anonymous classes are never registered implicitly, and a
  # subclass whose name no longer resolves back to it is dropped at the next
  # registry rebuild. Duplicate identifiers raise
  # Riffer::DuplicateIdentifierError at first lookup.
  #
  #--
  #: (String | Symbol) -> Class?
  def find(identifier)
    identifier_registry[identifier.to_s]
  end

  # Returns all registered subclasses, implicit and explicit. Carries the same
  # registration rules as +find+.
  #
  #--
  #: () -> Array[Class]
  def all
    identifier_registry.values
  end

  # Registers a direct subclass under its +identifier+, whether or not it is
  # named. Unlike implicit registration it survives a name that no longer
  # resolves, so an ephemeral class stays findable until +unregister+.
  #
  #   klass = Class.new(Riffer::Tool) { identifier "stub_tool" }
  #   Riffer::Tool.register(klass)
  #
  # Raises Riffer::ArgumentError when the identifier is blank or the class is
  # not a direct subclass, and Riffer::DuplicateIdentifierError when the
  # identifier is already taken — including by this same class.
  #
  #--
  #: (Class) -> void
  def register(klass)
    unless klass.superclass.equal?(self)
      raise Riffer::ArgumentError, "#{klass} must be a direct subclass of #{self} to register"
    end

    key = identifier_key(klass)
    raise Riffer::ArgumentError, "#{klass} must declare a non-blank identifier to register" if key.strip.empty?

    existing = identifier_registry[key]
    raise_duplicate_identifier!(key, existing, klass) if existing

    @explicit_registrations = explicit_registrations.merge(key => klass)
    @identifier_registry = nil
  end

  # Removes an explicit registration of +klass+, leaving implicit registrations
  # untouched.
  #--
  #: (Class) -> void
  def unregister(klass)
    @explicit_registrations = explicit_registrations.reject { |_key, registered| registered.equal?(klass) }
    @identifier_registry = nil
  end

  # Registers each class for the duration of the block and returns the block's
  # value.
  #
  #   Riffer::Tool.with_registered(stub_tool) do
  #     agent.generate("...")
  #   end
  #
  # Raises whatever +register+ raises, having first unregistered the classes it
  # already registered.
  #
  #--
  #: [T] (*Class) { () -> T } -> T
  def with_registered(*klasses)
    registered = [] #: Array[Class]

    begin
      klasses.each do |klass|
        register(klass)
        registered << klass
      end
    rescue StandardError
      unregister_all(registered)
      raise
    end

    begin
      yield
    ensure
      unregister_all(registered)
    end
  end

  private

  #--
  #: (Array[Class]) -> void
  def unregister_all(klasses)
    klasses.reverse_each { |klass| unregister(klass) }
  end

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
  def explicit_registrations
    @explicit_registrations ||= {}
  end

  #--
  #: () -> Hash[String, Class]
  def build_identifier_registry
    subclasses.each_with_object(explicit_registrations.dup) do |subclass, acc|
      next unless live?(subclass)

      key = identifier_key(subclass)
      next if key.strip.empty?

      existing = acc[key]
      raise_duplicate_identifier!(key, existing, subclass) if existing && !existing.equal?(subclass)

      acc[key] = subclass
    end.freeze
  end

  # Class#subclasses keeps returning superseded generations of a reloaded or
  # stubbed class, so a subclass counts only while its own name still resolves
  # back to it. An anonymous class has no name to resolve and is skipped even
  # with an explicit identifier — the MCP factory and serializer shells
  # synthesize short-lived anonymous classes whose registration would flake
  # with GC timing.
  #--
  #: (Class) -> bool
  def live?(subclass)
    real_name = Riffer::Helpers::Identifier.real_name(subclass)
    return false if real_name.nil?

    # Module#autoload? does not traverse a qualified path, so each segment is
    # resolved against its own owner: probing a pending autoload would trigger
    # the load, whose +inherited+ hook busts the memo this build is populating.
    root = Object #: Module
    resolved = real_name.split("::").reduce(root) do |owner, segment|
      return false if owner.autoload?(segment, false)

      owner.const_get(segment, false) #: Module
    end

    resolved.equal?(subclass)
  rescue NameError
    false
  end

  #--
  #: (Class) -> String
  def identifier_key(klass)
    candidate = klass #: untyped
    candidate.identifier.to_s
  end

  #--
  #: (String, Class, Class) -> void
  def raise_duplicate_identifier!(key, existing, klass)
    raise Riffer::DuplicateIdentifierError,
          "Duplicate identifier #{key.inspect} for #{existing} and #{klass}"
  end
end
