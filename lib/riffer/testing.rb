# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Testing
  extend self

  # @rbs self.@registrations: Array[[Class, String?]]?

  CONST_NAME_PATTERN = /\A[A-Z][A-Za-z0-9_]*\z/ #: Regexp
  private_constant :CONST_NAME_PATTERN

  #--
  #: (?(String | Symbol)?, ?base: singleton(Riffer::Agent)) ?{ () [self: singleton(Riffer::Agent)] -> void } -> singleton(Riffer::Agent)
  def stub_agent(name = nil, base: Riffer::Agent, &body)
    build_stub(name, base: base, &body) #: singleton(Riffer::Agent)
  end

  #--
  #: (?(String | Symbol)?, ?base: singleton(Riffer::Tool)) ?{ () [self: singleton(Riffer::Tool)] -> void } -> singleton(Riffer::Tool)
  def stub_tool(name = nil, base: Riffer::Tool, &body)
    build_stub(name, base: base, &body) #: singleton(Riffer::Tool)
  end

  #--
  #: () -> void
  def reset!
    tracked = Riffer::Testing.registrations
    tracked.reverse_each do |stub, const_name|
      registrable = stub.superclass #: untyped
      registrable.unregister(stub)
      remove_stub_const(const_name, stub) if const_name
    end
    tracked.clear
  end

  #--
  #: () -> Array[[Class, String?]]
  def self.registrations # :nodoc:
    # Lives on the module rather than the caller so an including test case and
    # a direct <tt>Riffer::Testing.stub_*</tt> call share one list. Not
    # synchronized: stub from a single-threaded test.
    @registrations ||= []
  end

  private

  #--
  #: ((String | Symbol)?, base: Class) ?{ () [self: untyped] -> void } -> Class
  def build_stub(name, base:, &body)
    const_name = validate_const_name(name)
    stub = Class.new(base)
    configurable = stub #: untyped
    configurable.identifier(Riffer::Helpers::Identifier.derive(const_name)) if const_name
    configurable.class_eval(&body) if body
    if configurable.identifier.to_s.strip.empty?
      raise Riffer::ArgumentError, "a stub needs a name, or an identifier set in its block"
    end

    # The class must be registered while still anonymous: naming it first makes
    # it implicitly live, and +register+ rejects an identifier the registry
    # already resolves — even to this same class.
    registrable = base #: untyped
    registrable.register(stub)
    Object.const_set(const_name, stub) if const_name
    Riffer::Testing.registrations << [stub, const_name]

    stub
  end

  #--
  #: ((String | Symbol)?) -> String?
  def validate_const_name(name)
    return nil if name.nil?

    const_name = name.to_s
    unless CONST_NAME_PATTERN.match?(const_name)
      raise Riffer::ArgumentError, "#{const_name.inspect} is not a simple top-level constant name"
    end

    # True of a pending autoload too — the name is taken either way.
    if Object.const_defined?(const_name, false)
      raise Riffer::ArgumentError, "#{const_name} is already defined; use stub_const to replace a real class"
    end

    const_name
  end

  #--
  #: (String, Class) -> void
  def remove_stub_const(const_name, stub)
    # A test may have removed or replaced the constant itself, so never clobber
    # one that no longer points at the stub.
    return unless Object.const_defined?(const_name, false) && Object.const_get(const_name, false).equal?(stub)

    Object.send(:remove_const, const_name)
  end
end
