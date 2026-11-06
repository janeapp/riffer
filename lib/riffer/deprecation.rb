# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Deprecation
  extend self

  # @rbs @mutex: Thread::Mutex
  # @rbs @reported: Set[[Symbol, String?]]

  MODES = %i[warn raise silence].freeze #: Array[Symbol]

  LIB_DIR = "#{File.dirname(__FILE__, 2)}/".freeze #: String
  ALLOWED_KEY = :riffer_deprecations_allowed #: Symbol
  private_constant :LIB_DIR, :ALLOWED_KEY

  @mutex = Mutex.new
  @reported = Set.new

  #--
  #: (id: Symbol, message: String) -> void
  def warn(id:, message:)
    return if Fiber[ALLOWED_KEY]

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
      callable.call(event) if first_report?(event)
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
  #: (Event) -> bool
  def first_report?(event)
    !@mutex.synchronize { @reported.add?([event.id, event.location]) }.nil?
  end
end
