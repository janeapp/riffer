# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StreamEvents::WebSearchStatus < Riffer::StreamEvents::Base
  attr_reader :status #: String
  attr_reader :url #: String?
  attr_reader :query #: String?

  #: (String, ?url: String?, ?query: String?, ?role: Symbol) -> void
  def initialize(status, url: nil, query: nil, role: :assistant)
    super(role: role)
    @status = status
    @url = url
    @query = query
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    h = {role: @role, status: @status}
    h[:url] = @url if @url
    h[:query] = @query if @query
    h
  end
end
