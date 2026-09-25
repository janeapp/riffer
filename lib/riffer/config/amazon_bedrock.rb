# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config::AmazonBedrock
  attr_reader :api_token #: String? # @dynamic api_token

  attr_reader :region #: String? # @dynamic region

  attr_accessor :client #: untyped # @dynamic client, client=

  #--
  #: () -> void
  def initialize
    @api_token = nil
    @region = nil
    @client = nil
  end

  #--
  #: (untyped) -> void
  def api_token=(value)
    @api_token = Riffer::Helpers::Validate.optional_string(value, attribute: "api_token")
  end

  #--
  #: (untyped) -> void
  def region=(value)
    @region = Riffer::Helpers::Validate.optional_string(value, attribute: "region")
  end
end
