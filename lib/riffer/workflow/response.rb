# frozen_string_literal: true
# rbs_inline: enabled

# Wraps workflow responses.
#
#   response = workflow.run("Hello")
#   puts response.steps_response
class Riffer::Workflow::Response
  # The workflow identifier
  attr_reader :identifier #: String

  # The output of each agent
  attr_reader :steps_response #: Hash[Symbol, Riffer::Agent::Response|Riffer::Tool::Response]

  # The error message when something fail
  attr_reader :error_message #: String?

  # The error type that causes the workflow to fail
  attr_reader :error_type #: Symbol?

  # Creates a success response.
  #
  #--
  #: (identifier: String, steps_response: Hash[Symbol, Riffer::Agent::Response|Riffer::Tool::Response]) -> Riffer::Workflow::Response
  def self.success(identifier:, steps_response:)
    new(identifier: identifier, success: true, steps_response: steps_response)
  end

  # Creates an error response.
  #
  #--
  #: (identifier: String, steps_response: Hash[Symbol, Riffer::Agent::Response|Riffer::Tool::Response], message: String, ?type: Symbol) -> Riffer::Workflow::Response
  def self.error(identifier:, steps_response:, message:, type: :execution_error)
    new(identifier: identifier, success: false, steps_response: steps_response,
      error_message: message, error_type: type)
  end

  #--
  #: () -> bool
  def success? = @success

  #--
  #: () -> bool
  def error? = !@success

  private

  #--
  #: (identifier: String, success: bool, steps_response: Hash[Symbol, Riffer::Agent::Response|Riffer::Tool::Response], ?error_message: String?, ?error_type: Symbol?) -> void
  def initialize(identifier:, success:, steps_response:, error_message: nil, error_type: nil)
    @identifier = identifier
    @steps_response = steps_response
    @success = success
    @error_message = error_message
    @error_type = error_type
  end
end
