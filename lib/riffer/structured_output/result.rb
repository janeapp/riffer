# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StructuredOutput::Result
  attr_reader :object #: Hash[Symbol, untyped]?
  attr_reader :error #: String?

  #: (?object: Hash[Symbol, untyped]?, ?error: String?) -> void
  def initialize(object: nil, error: nil)
    @object = object
    @error = error
  end

  #: () -> bool
  def success? = @error.nil?

  #: () -> bool
  def failure? = !success?
end
