# frozen_string_literal: true
# rbs_inline: enabled

# Thread-safe per-instance store of exposed +Riffer::Tool+ subclasses.
#
# Each registration is a +{tool_class:, scope:}+ record. The same tool can be
# registered multiple times (under different scopes); +#lookup+ returns the
# most recent record. All public methods are mutex-guarded.
class Riffer::McpServer::Registry
  #: () -> void
  def initialize
    @mutex = Mutex.new
    @records = [] #: Array[Hash[Symbol, untyped]]
  end

  # Registers a tool class under the given scope. The same tool may be
  # registered repeatedly under different scopes.
  #
  #--
  #: (Class, ?scope: (Symbol | Array[Symbol])) -> Hash[Symbol, untyped]
  def register(tool_class, scope: :default)
    record = {tool_class: tool_class, scope: scope}
    @mutex.synchronize { @records << record }
    record
  end

  # Returns the most-recently-registered record whose tool name matches.
  # Returns +nil+ when no record matches.
  #
  #--
  #: (String) -> Hash[Symbol, untyped]?
  def lookup(name)
    @mutex.synchronize do
      result = nil
      @records.each { |r| result = r if r[:tool_class].name == name }
      result
    end
  end

  # Returns all records whose scope matches +scope+ (Symbol equality, or
  # Array#include? when the record's scope is an Array).
  #
  #--
  #: (Symbol) -> Array[Hash[Symbol, untyped]]
  def all_for_scope(scope)
    @mutex.synchronize do
      @records.select do |r|
        rec_scope = r[:scope]
        rec_scope.is_a?(Array) ? rec_scope.include?(scope) : rec_scope == scope
      end
    end
  end

  # Returns a frozen snapshot of all records. Mutating the snapshot does not
  # affect the registry.
  #
  #--
  #: () -> Array[Hash[Symbol, untyped]]
  def all
    @mutex.synchronize { @records.dup.freeze }
  end

  # Removes every registration.
  #
  #--
  #: () -> void
  def clear!
    @mutex.synchronize { @records.clear }
  end
end
