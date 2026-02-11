# frozen_string_literal: true

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
  #
  # Returns String.
  attr_reader :content

  # The tripwire if execution was blocked.
  #
  # Returns Riffer::Guardrails::Tripwire or nil.
  attr_reader :tripwire

  # Creates a new response.
  #
  # content:: String - the response content
  # tripwire:: Riffer::Guardrails::Tripwire or nil - optional tripwire for blocked responses
  def initialize(content, tripwire: nil)
    @content = content
    @tripwire = tripwire
  end

  # Returns true if the response was blocked by a guardrail.
  #
  # Returns Boolean.
  def blocked?
    !tripwire.nil?
  end
end
