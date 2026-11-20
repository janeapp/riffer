# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Deprecation
  extend self

  # @rbs @mutex: Thread::Mutex
  # @rbs @reported: Set[[Symbol, String?]]

  MODES = %i[warn raise silence].freeze #: Array[Symbol]

  LIB_DIR = "#{File.dirname(__FILE__, 2)}/".freeze #: String
  ALLOWED_KEY = :riffer_deprecations_allowed #: Symbol
  ONCE_PER_LINE_MESSAGE = "Calling config.deprecations callables once per deprecation per calling line is " \
                          "deprecated; a future version will call them on every report. Set " \
                          "config.future.deprecation_callable_every_report = true to opt in now." #: String
  private_constant :LIB_DIR, :ALLOWED_KEY, :ONCE_PER_LINE_MESSAGE

  @mutex = Mutex.new
  @reported = Set.new

  #--
  #: (id: Symbol, message: String) -> void
  def warn(id:, message:)
    return if Fiber[ALLOWED_KEY] || silenced?(id)

    frame = caller_locations&.find { |location| !location.path.to_s.start_with?(LIB_DIR) }
    location = frame && "#{frame.path}:#{frame.lineno}"
    event = Event.new(id: id, message: message, location: location)

    case (handler = Riffer.config.deprecations)
    when :silence then nil
    # Every call, not once per line, so a suite in :raise mode fails on each offending test.
    when :raise then raise Riffer::DeprecationError, event.to_s
    when :warn then Kernel.warn(event.to_s) if first_report?(event)
    else
      callable = handler #: ^(Event) -> void
      call_handler(callable, event)
    end
  end

  #--
  #: [T] () { () -> T } -> T
  def allow
    previous = Fiber[ALLOWED_KEY] #: bool?
    # Fiber storage is inherited by threads and fibers spawned inside the block,
    # so work the block fans out stays silenced while other threads are not.
    Fiber[ALLOWED_KEY] = true
    begin
      yield
    ensure
      Fiber[ALLOWED_KEY] = previous
    end
  end

  private

  #--
  #: (Symbol) -> bool
  def silenced?(id)
    Riffer.config.silenced_deprecations.include?(id)
  end

  #--
  #: (^(Event) -> void, Event) -> void
  def call_handler(callable, event)
    if Riffer.config.future.enabled?(:deprecation_callable_every_report)
      callable.call(event)
    elsif first_report?(event)
      callable.call(event)
      notice = Event.new(id: :deprecation_callable_once_per_line, message: ONCE_PER_LINE_MESSAGE, location: nil)
      callable.call(notice) if !silenced?(notice.id) && first_report?(notice)
    end
  end

  #--
  #: (Event) -> bool
  def first_report?(event)
    !@mutex.synchronize { @reported.add?([event.id, event.location]) }.nil?
  end
end
