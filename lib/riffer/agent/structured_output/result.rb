# frozen_string_literal: true
# rbs_inline: enabled

# Wraps the result of structured output parsing and validation.
#
#   result = structured_output.parse_and_validate(json_string)
#   if result.success?
#     result.object  #=> {sentiment: "positive", score: 0.9}
#   else
#     result.error   #=> "JSON parse error: ..."
#   end
#
class Riffer::Agent::StructuredOutput::Result
  # The validated object, or +nil+ on failure.
  attr_reader :object #: Hash[Symbol, untyped]?

  # The error message, or +nil+ on success.
  attr_reader :error #: String?

  #--
  #: (?object: Hash[Symbol, untyped]?, ?error: String?) -> void
  def initialize(object: nil, error: nil)
    @object = object
    @error = error
  end

  # Returns true when parsing and validation succeeded.
  #
  #--
  #: () -> bool
  def success? = @error.nil?

  # Returns true when parsing or validation failed.
  #
  #--
  #: () -> bool
  def failure? = !success?
end
