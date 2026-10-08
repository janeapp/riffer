# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config::GoogleCloud
  attr_reader :project_id #: String? # @dynamic project_id

  # The default +"global"+ endpoint routes requests to any region, so it
  # carries no data-residency guarantee.
  attr_reader :location #: String # @dynamic location

  # A googleauth credentials object; +nil+ resolves Application Default
  # Credentials.
  attr_accessor :credentials #: untyped # @dynamic credentials, credentials=

  attr_accessor :client #: untyped # @dynamic client, client=

  #--
  #: () -> void
  def initialize
    @project_id = nil
    @location = "global"
    @credentials = nil
    @client = nil
  end

  #--
  #: (untyped) -> void
  def project_id=(value)
    @project_id = Riffer::Helpers::Validate.optional_string(value, attribute: "project_id")
  end

  # +nil+ restores the +"global"+ default.
  #--
  #: (untyped) -> void
  def location=(value)
    @location = Riffer::Helpers::Validate.optional_string(value, attribute: "location") || "global"
  end
end
