# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config::OpenRouter
  attr_reader :api_key #: String? # @dynamic api_key

  attr_accessor :client #: untyped # @dynamic client, client=

  #--
  #: () -> void
  def initialize
    @api_key = nil
    @client = nil
  end

  #--
  #: (untyped) -> void
  def api_key=(value)
    @api_key = Riffer::Helpers::Validate.optional_string(value, attribute: "api_key")
  end
end
