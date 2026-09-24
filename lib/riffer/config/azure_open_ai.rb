# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config::AzureOpenAI
  attr_reader :api_key #: String? # @dynamic api_key

  attr_reader :endpoint #: String? # @dynamic endpoint

  attr_accessor :client #: untyped # @dynamic client, client=

  #--
  #: () -> void
  def initialize
    @api_key = nil
    @endpoint = nil
    @client = nil
  end

  #--
  #: (untyped) -> void
  def api_key=(value)
    @api_key = Riffer::Helpers::Validate.optional_string(value, attribute: "api_key")
  end

  #--
  #: (untyped) -> void
  def endpoint=(value)
    @endpoint = Riffer::Helpers::Validate.optional_string(value, attribute: "endpoint")
  end
end
