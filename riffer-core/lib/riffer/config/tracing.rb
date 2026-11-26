# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config::Tracing
  attr_reader :enabled #: bool # @dynamic enabled

  attr_reader :capture_messages #: bool # @dynamic capture_messages

  attr_reader :backend #: untyped # @dynamic backend

  #--
  #: () -> void
  def initialize
    # Spans are a no-op until a host wires an OTEL SDK.
    @enabled = true
    # Message content routinely carries sensitive data.
    @capture_messages = false
    @backend = nil
  end

  #--
  #: (untyped) -> void
  def enabled=(value)
    @enabled = Riffer::Helpers::Boolean.coerce(value, attribute: "enabled")
  end

  #--
  #: (untyped) -> void
  def capture_messages=(value)
    @capture_messages = Riffer::Helpers::Boolean.coerce(value, attribute: "capture_messages")
  end

  #--
  #: (untyped) -> void
  def backend=(value)
    contract = %i[in_span current_context with_context]
    unless value.nil? || contract.all? { |method| value.respond_to?(method) }
      raise Riffer::ArgumentError, "tracing backend must respond to #in_span, #current_context, and #with_context"
    end

    @backend = value
  end
end
