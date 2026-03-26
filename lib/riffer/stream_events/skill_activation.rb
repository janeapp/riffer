# frozen_string_literal: true
# rbs_inline: enabled

# Emitted when a skill is activated during streaming.
#
# Fired by the +on_activate+ callback on Riffer::Skills::Context
# when the LLM calls the skill activation tool.
class Riffer::StreamEvents::SkillActivation < Riffer::StreamEvents::Base
  # The activated skill name.
  attr_reader :name #: String

  #--
  #: (String, ?role: Symbol) -> void
  def initialize(name, role: :system)
    super(role: role)
    @name = name
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: @role, name: @name}
  end
end
