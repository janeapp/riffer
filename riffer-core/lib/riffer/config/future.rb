# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config::Future
  # Steep can't type an empty literal; drop the ignore once FLAGS has an entry.
  # steep:ignore:start
  FLAGS = {}.freeze #: Hash[Symbol, { default: bool }]
  # steep:ignore:end

  # @rbs @flags: Hash[Symbol, { default: bool }]
  # @rbs @enabled: Hash[Symbol, bool]

  #--
  #: (?flags: Hash[Symbol, { default: bool }]) -> void
  def initialize(flags: FLAGS)
    @flags = flags
    @enabled = {}
    flags.each_key { |name| define_singleton_method(:"#{name}=") { |value| set(name, value) } }
  end

  #--
  #: (Symbol) -> bool
  def enabled?(name)
    flag(name)[:default] || @enabled.fetch(name, false)
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
