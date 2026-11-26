# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Agent::StructuredOutput::Result
  attr_reader :object #: Hash[Symbol, untyped]? # @dynamic object
  attr_reader :error #: String? # @dynamic error

  attr_reader :json #: String? # @dynamic json

  #--
  #: (?object: Hash[Symbol, untyped]?, ?error: String?, ?json: String?) -> void
  def initialize(object: nil, error: nil, json: nil)
    @object = object
    @error = error
    @json = json
  end

  #--
  #: () -> bool
  def success? = @error.nil?

  #--
  #: () -> bool
  def failure? = !success?
end
