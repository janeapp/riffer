# frozen_string_literal: true
# rbs_inline: enabled

# A web search status notification, emitted as a server-side web search
# progresses.
class Riffer::StreamEvents::WebSearchStatus < Riffer::StreamEvents::Base
  # The web search status ("in_progress", "searching", "completed", "open_page").
  attr_reader :status #: String

  # The URL being fetched (present for "open_page" status).
  attr_reader :url #: String?

  # The search query (present when available during status changes).
  attr_reader :query #: String?

  #--
  #: (String, ?url: String?, ?query: String?, ?role: Symbol) -> void
  def initialize(status, url: nil, query: nil, role: :assistant)
    super(role: role)
    @status = status
    @url = url
    @query = query
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    h = { role: @role, status: @status } #: Hash[Symbol, untyped]
    h[:url] = @url if @url
    h[:query] = @query if @query
    h
  end
end
