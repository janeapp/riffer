# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StreamEvents::WebSearchDone < Riffer::StreamEvents::Base
  attr_reader :query #: String # @dynamic query

  attr_reader :sources #: Array[Hash[Symbol, String?]] # @dynamic sources

  #--
  #: (String, ?sources: Array[Hash[Symbol, String?]], ?role: Symbol) -> void
  def initialize(query, sources: [], role: :assistant)
    super(role: role)
    @query = query
    @sources = sources
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    { role: @role, query: @query, sources: @sources }
  end
end
