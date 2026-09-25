# frozen_string_literal: true
# rbs_inline: enabled

# @rbs module-self Class
module Riffer::Registrable
  # @rbs @identifier_registry: Hash[String, Class]?
  # @rbs @explicit_registrations: Hash[String, Class]?

  #--
  #: (String | Symbol) -> Class?
  def find(identifier)
    identifier_registry[identifier.to_s]
  end

  #--
  #: () -> Array[Class]
  def all
    identifier_registry.values
  end

  # Whether the registry covers every descendant rather than only direct subclasses. A base whose
  # subclasses are themselves subclassed overrides this, so an identifier resolves from any ancestor.
  #--
  #: () -> bool
  def registers_descendants?
    false
  end

  #--
  #: (Class) -> void
  def register(klass)
    unless registrable?(klass)
      relation = registers_descendants? ? "descendant" : "direct subclass"
      raise Riffer::ArgumentError, "#{klass} must be a #{relation} of #{self} to register"
    end

    key = identifier_key(klass)
    raise Riffer::ArgumentError, "#{klass} must declare a non-blank identifier to register" if key.strip.empty?

    existing = identifier_registry[key]
    raise_duplicate_identifier!(key, existing, klass) if existing

    # Not synchronized: register during boot or from a single-threaded test,
    # before concurrent lookups begin.
    explicit_registrations[key] = klass
    @identifier_registry = nil
  end

  #--
  #: (Class) -> void
  def unregister(klass)
    key, = explicit_registrations.find { |_key, registered| registered.equal?(klass) }
    return if key.nil?

    explicit_registrations.delete(key)
    @identifier_registry = nil
  end

  private

  #--
  #: (Class) -> void
  def inherited(subclass)
    super
    # The new class joins its direct superclass's registry, and every ancestor's as well where those
    # register descendants, so each of those memos is stale now.
    registry = self #: untyped
    while registry.singleton_class.include?(Riffer::Registrable)
      registry.instance_variable_set(:@identifier_registry, nil)
      break unless registry.registers_descendants?

      registry = registry.superclass
    end
  end

  #--
  #: (Class) -> bool
  def registrable?(klass)
    return klass.superclass.equal?(self) unless registers_descendants?

    (klass < self) == true
  end

  #--
  #: () -> Array[Class]
  def registry_candidates
    return subclasses unless registers_descendants?

    found = [] #: Array[Class]
    pending = subclasses.dup
    until pending.empty?
      klass = pending.shift #: Class
      found << klass
      pending.concat(klass.subclasses)
    end
    found
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
    # Explicit entries skip +live?+ so an ephemeral class stays findable until
    # +unregister+, even once its name no longer resolves.
    registry_candidates.each_with_object(explicit_registrations.dup) do |subclass, acc|
      next unless live?(subclass)

      key = identifier_key(subclass)
      next if key.strip.empty?

      existing = acc[key]
      raise_duplicate_identifier!(key, existing, subclass) if existing && !existing.equal?(subclass)

      acc[key] = subclass
    end.freeze
  end

  #--
  #: (Class) -> bool
  def live?(subclass)
    # Class#subclasses keeps returning superseded generations of a reloaded or
    # stubbed class, so a subclass counts only while its own name still
    # resolves back to it. Anonymous classes are skipped even with an
    # identifier: the MCP factory and serializer shells synthesize short-lived
    # anonymous classes whose registration would flake with GC timing.
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
