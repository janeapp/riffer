# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Mcp::Registry
  extend self

  # @rbs @mutex: Thread::Mutex
  # @rbs @store: Hash[String, Riffer::Mcp::Registration]

  @mutex = Mutex.new
  @store = {} #: Hash[String, Riffer::Mcp::Registration]

  #--
  #: ((Hash[Symbol, untyped] | Riffer::Mcp::Manifest)) -> Riffer::Mcp::Registration
  def register(manifest_or_hash)
    # steep cannot verify that an untyped Hash splat supplies Manifest's
    # required name:/endpoint: keywords; Manifest validates them at runtime.
    manifest = if manifest_or_hash.is_a?(Riffer::Mcp::Manifest)
                 manifest_or_hash
               else
                 Riffer::Mcp::Manifest.new(**manifest_or_hash) # steep:ignore InsufficientKeywordArguments
               end
    registration = Riffer::Mcp::Registration.new(manifest)
    old = @mutex.synchronize do
      previous = @store[manifest.name]
      @store[manifest.name] = registration
      previous
    end
    old&.retire!
    registration
  end

  #--
  #: ((String | Symbol)) -> void
  def unregister(name)
    removed = @mutex.synchronize { @store.delete(name.to_s) }
    removed&.retire!
  end

  #--
  #: () -> Hash[String, Riffer::Mcp::Registration]
  def registrations
    @mutex.synchronize { @store.dup.freeze }
  end

  #--
  #: (Array[Symbol]) -> Array[Riffer::Mcp::Registration]
  def find_by_tags(tags)
    normalized = tags.map(&:to_sym)
    @mutex.synchronize do
      @store.values.select { |reg| reg.manifest.tags.intersect?(normalized) }
    end
  end
end
