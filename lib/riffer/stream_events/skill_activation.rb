# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StreamEvents::SkillActivation < Riffer::StreamEvents::Base
  attr_reader :name #: String

  #: (String, ?role: Symbol) -> void
  def initialize(name, role: :system)
    super(role: role)
    @name = name
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: @role, name: @name}
  end
end
