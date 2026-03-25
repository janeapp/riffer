# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Skills::Config
  #: () -> void
  def initialize
    @backend = nil
    @adapter = nil
    @activate = nil
  end

  #: (?(Riffer::Skills::Backend | Proc)?) -> (Riffer::Skills::Backend | Proc)?
  def backend(value = nil)
    return @backend if value.nil?
    @backend = value
  end

  #: (?singleton(Riffer::Skills::Adapter)?) -> singleton(Riffer::Skills::Adapter)?
  def adapter(value = nil)
    return @adapter if value.nil?
    @adapter = value
  end

  #: (?(Array[String] | Proc)?) -> (Array[String] | Proc)?
  def activate(value = nil)
    return @activate if value.nil?
    @activate = value
  end
end
