# frozen_string_literal: true
# rbs_inline: enabled

# Builds throwaway agents and tools a test suite can resolve by identifier, and
# removes them again. Require <tt>riffer/testing/rspec</tt> or
# <tt>riffer/testing/minitest</tt> to get +stub_agent+/+stub_tool+ in every
# example plus per-test cleanup; otherwise include this module and call +reset!+
# from your own teardown, or call the methods on the module directly.
#
# Tracking is not synchronized — stub from a single-threaded test, before
# concurrent lookups begin.
module Riffer::Testing
  extend self

  # @rbs self.@registrations: Array[Class]?

  # Builds an agent class under +identifier+, evaluates the optional body in it,
  # and makes it resolvable until the next +reset!+.
  #
  #   agent = stub_agent(identifier: "support_agent") { model "mock/gpt-5-mini" }
  #
  # Raises Riffer::DuplicateIdentifierError when another agent already holds the
  # identifier.
  #
  #--
  #: (identifier: (String | Symbol), ?base: singleton(Riffer::Agent)) ?{ () [self: singleton(Riffer::Agent)] -> void } -> singleton(Riffer::Agent)
  def stub_agent(identifier:, base: Riffer::Agent, &body)
    build_stub(base: base, identifier: identifier, &body) #: singleton(Riffer::Agent)
  end

  # Builds a tool class under +identifier+, evaluates the optional body in it,
  # and makes it resolvable until the next +reset!+.
  #
  #   tool = stub_tool(identifier: "kb_search") do
  #     def call(context:, **) = text("stubbed")
  #   end
  #
  # Raises Riffer::DuplicateIdentifierError when another tool already holds the
  # identifier.
  #
  #--
  #: (identifier: (String | Symbol), ?base: singleton(Riffer::Tool)) ?{ () [self: singleton(Riffer::Tool)] -> void } -> singleton(Riffer::Tool)
  def stub_tool(identifier:, base: Riffer::Tool, &body)
    build_stub(base: base, identifier: identifier, &body) #: singleton(Riffer::Tool)
  end

  # Removes every stub built since the last reset, newest first, and forgets
  # them. A no-op when nothing has been stubbed.
  #--
  #: () -> void
  def reset!
    tracked = Riffer::Testing.registrations
    tracked.reverse_each do |stub|
      registrable = stub.superclass #: untyped
      registrable.unregister(stub)
    end
    tracked.clear
  end

  # The stub classes awaiting cleanup. Lives on the module rather than the
  # caller so an including test case and a direct <tt>Riffer::Testing.stub_*</tt>
  # call share one list.
  #--
  #: () -> Array[Class]
  def self.registrations # :nodoc:
    @registrations ||= []
  end

  private

  #--
  #: (base: Class, identifier: (String | Symbol)) ?{ () [self: untyped] -> void } -> Class
  def build_stub(base:, identifier:, &body)
    stub = Class.new(base)
    configurable = stub #: untyped
    configurable.identifier(identifier.to_s)
    configurable.class_eval(&body) if body

    registrable = base #: untyped
    registrable.register(stub)
    Riffer::Testing.registrations << stub

    stub
  end
end
