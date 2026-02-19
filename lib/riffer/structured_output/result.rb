# frozen_string_literal: true
# rbs_inline: enabled

# Wraps the result of structured output parsing and validation.
#
# On success, +object+ contains the validated Hash and +error+ is nil.
# On failure, +error+ contains the error message and +object+ is nil.
#
#   result = structured_output.parse_and_validate(json_string)
#   if result.success?
#     result.object  #=> {sentiment: "positive", score: 0.9}
#   else
#     result.error   #=> "JSON parse error: ..."
#   end
#
class Riffer::StructuredOutput::Result
  attr_reader :object #: Hash[Symbol, untyped]?
  attr_reader :error #: String?

  #: (?object: Hash[Symbol, untyped]?, ?error: String?) -> void
  def initialize(object: nil, error: nil)
    @object = object
    @error = error
  end

  # Returns true when parsing and validation succeeded.
  #
  #: () -> bool
  def success? = @error.nil?

  # Returns true when parsing or validation failed.
  #
  #: () -> bool
  def failure? = !success?
end
