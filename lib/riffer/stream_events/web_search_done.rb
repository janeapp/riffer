# frozen_string_literal: true
# rbs_inline: enabled

# Represents the result of a web search during streaming.
#
# Emitted when the LLM has finished a server-side web search.
class Riffer::StreamEvents::WebSearchDone < Riffer::StreamEvents::Base
  # The search query used.
  attr_reader :query #: String

  # The search result sources with title and url.
  attr_reader :sources #: Array[Hash[Symbol, String?]]

  #: (String, ?sources: Array[Hash[Symbol, String?]], ?role: Symbol) -> void
  def initialize(query, sources: [], role: :assistant)
    super(role: role)
    @query = query
    @sources = sources
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: @role, query: @query, sources: @sources}
  end
end
