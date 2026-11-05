# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Deprecation
  MODES = %i[warn raise silence].freeze #: Array[Symbol]

  Event = Data.define(
    :id, #: Symbol
    :message, #: String
    :removed_in, #: String
    :location, #: String?
  )

  class Event
    #--
    #: () -> String
    def to_s
      text = "riffer: #{message} It will be removed in riffer #{removed_in}."
      location ? "#{text} Called from #{location}." : text
    end
  end

  LIB_DIR = "#{File.dirname(__FILE__, 2)}/".freeze #: String
  ALLOWED_KEY = :riffer_deprecations_allowed #: Symbol
  private_constant :LIB_DIR, :ALLOWED_KEY

  # @rbs self.@mutex: Thread::Mutex
  # @rbs self.@reported: Set[[Symbol, String?]]

  @mutex = Mutex.new
  @reported = Set.new

  #--
  #: (id: Symbol, message: String, removed_in: String) -> void
  def self.warn(id:, message:, removed_in:)
    return if Fiber[ALLOWED_KEY]

    frame = caller_locations&.find { |location| !location.path.to_s.start_with?(LIB_DIR) }
    location = frame && "#{frame.path}:#{frame.lineno}"
    event = Event.new(id: id, message: message, removed_in: removed_in, location: location)

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
  def self.allow
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

  #--
  #: (Event) -> bool
  def self.first_report?(event)
    !@mutex.synchronize { @reported.add?([event.id, event.location]) }.nil?
  end
  private_class_method :first_report?
end
