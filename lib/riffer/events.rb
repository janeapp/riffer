# frozen_string_literal: true
# rbs_inline: enabled

# Synchronous in-process event bus. Riffer publishes one completion event per
# instrumented operation, and subscribers registered through +config.events+
# receive every event. Observability backends (metrics, Datadog, logs) are
# subscribers, so observability never couples to one vendor.
module Riffer::Events
  extend self

  # Whether any subscriber is registered. Call sites build an event only when
  # someone is listening, so an idle bus costs nothing.
  #--
  #: () -> bool
  def subscribed?
    Riffer.config.events.subscribers.any?
  end

  # Publishes an event to every subscriber synchronously, in registration order.
  # A subscriber that raises is isolated — the error routes to
  # +config.events.on_error+ and delivery continues — so an observability
  # failure never breaks the operation that produced the event.
  #--
  #: (Riffer::Events::Base) -> void
  def publish(event)
    events_config = Riffer.config.events
    events_config.subscribers.each do |subscriber|
      subscriber.call(event)
    rescue => error
      handle_error(events_config.on_error, error, event)
    end
  end

  private

  # The error handler is the last line of defense; if it raises too there's
  # nowhere left to route, so swallow to keep delivery going to the next
  # subscriber.
  #--
  #: (^(Exception, Riffer::Events::Base) -> void, Exception, Riffer::Events::Base) -> void
  def handle_error(handler, error, event)
    handler.call(error, event)
  rescue
    nil
  end
end
