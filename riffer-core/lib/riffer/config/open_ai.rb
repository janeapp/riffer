# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config::OpenAI
  attr_reader :api_key #: String? # @dynamic api_key

  attr_reader :base_url #: String? # @dynamic base_url

  attr_accessor :client #: untyped # @dynamic client, client=

  #--
  #: () -> void
  def initialize
    @api_key = nil
    @base_url = nil
    @client = nil
  end

  #--
  #: (untyped) -> void
  def api_key=(value)
    @api_key = Riffer::Helpers::Validate.optional_string(value, attribute: "api_key")
  end

  #--
  #: (untyped) -> void
  def base_url=(value)
    @base_url = Riffer::Helpers::Validate.optional_string(value, attribute: "base_url")
  end
end
