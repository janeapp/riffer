# frozen_string_literal: true
# rbs_inline: enabled

# Wraps agent generation responses with optional tripwire information.
#
# When guardrails block execution, the response will contain a tripwire
# with details about the block. The content will be empty for blocked responses.
#
#   response = agent.generate("Hello")
#   if response.blocked?
#     puts "Blocked: #{response.tripwire.reason}"
#   else
#     puts response.content
#   end
class Riffer::Agent::Response
  # The response content.
  attr_reader :content #: String

  # The tripwire if execution was blocked.
  attr_reader :tripwire #: Riffer::Guardrails::Tripwire?

  # Creates a new response.
  #
  # +content+ - the response content.
  # +tripwire+ - optional tripwire for blocked responses.
  #
  #: (String, ?tripwire: Riffer::Guardrails::Tripwire?) -> void
  def initialize(content, tripwire: nil)
    @content = content
    @tripwire = tripwire
  end

  # Returns true if the response was blocked by a guardrail.
  #
  #: () -> bool
  def blocked?
    !tripwire.nil?
  end
end
