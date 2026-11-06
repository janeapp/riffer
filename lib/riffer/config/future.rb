# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config::Future
  no_flags = {} #: Hash[Symbol, { default: bool }]

  FLAGS = no_flags.freeze #: Hash[Symbol, { default: bool }]

  # @rbs @flags: Hash[Symbol, { default: bool }]
  # @rbs @enabled: Hash[Symbol, bool]

  #--
  #: (?flags: Hash[Symbol, { default: bool }]) -> void
  def initialize(flags: FLAGS)
    @flags = flags
    @enabled = {}
  end

  #--
  #: (Symbol) -> bool
  def enabled?(name)
    flag(name)[:default] || @enabled.fetch(name, false)
  end

  #--
  #: (Symbol, *untyped) -> untyped
  def method_missing(method_name, *args)
    return super unless method_name.end_with?("=") && args.size == 1

    set(method_name.to_s.delete_suffix("=").to_sym, args.first)
  end

  #--
  #: (Symbol, ?bool) -> bool
  def respond_to_missing?(method_name, include_private = false)
    (method_name.end_with?("=") && @flags.key?(method_name.to_s.delete_suffix("=").to_sym)) || super
  end

  private

  #--
  #: (Symbol, untyped) -> void
  def set(name, value)
    graduated = flag(name)[:default]
    enabled = Riffer::Helpers::Boolean.coerce(value, attribute: "config.future.#{name}")

    if graduated
      Riffer::Deprecation.warn(
        id: :"future_#{name}",
        message: "config.future.#{name} is now the default and setting it has no effect; remove it.",
      )
    end

    @enabled[name] = enabled
  end

  #--
  #: (Symbol) -> { default: bool }
  def flag(name)
    @flags.fetch(name) do
      known = @flags.empty? ? "none" : @flags.keys.map(&:inspect).join(", ")
      raise Riffer::ArgumentError, "unknown future flag #{name.inspect} (known flags: #{known})"
    end
  end
end
