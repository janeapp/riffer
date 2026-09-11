# frozen_string_literal: true
# rbs_inline: enabled

# Represents completed reasoning during streaming; only emitted by providers
# that support reasoning (e.g. OpenAI with the reasoning option). +signature+
# and +redacted_data+ carry the opaque replay token, and exist only for the
# providers that sign reasoning (Anthropic, Amazon Bedrock).
class Riffer::StreamEvents::ReasoningDone < Riffer::StreamEvents::Base
  # The complete reasoning content.
  attr_reader :content #: String

  # The provider's verification token for this reasoning block.
  attr_reader :signature #: String?

  # The provider's encrypted stand-in for reasoning it redacted for safety.
  attr_reader :redacted_data #: String?

  #--
  #: (String, ?signature: String?, ?redacted_data: String?, ?role: Symbol) -> void
  def initialize(content, signature: nil, redacted_data: nil, role: :assistant)
    super(role: role)
    @content = content
    @signature = signature
    @redacted_data = redacted_data
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = { role: @role, content: @content } #: Hash[Symbol, untyped]
    hash[:signature] = @signature if @signature
    hash[:redacted_data] = @redacted_data if @redacted_data
    hash
  end
end
