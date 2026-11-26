# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StreamEvents::WebSearchStatus < Riffer::StreamEvents::Base
  # One of "in_progress", "searching", "open_page", or "completed".
  attr_reader :status #: String # @dynamic status

  attr_reader :url #: String? # @dynamic url

  attr_reader :query #: String? # @dynamic query

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
