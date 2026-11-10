# frozen_string_literal: true
# rbs_inline: enabled

# @deprecated Subclass Riffer::Tool instead.
module Riffer::Tools::Toolable
  #--
  #: (Module) -> void
  def self.extended(_base)
    Riffer::Deprecation.warn(
      id: :tools_toolable,
      message: "Riffer::Tools::Toolable is deprecated; subclass Riffer::Tool instead.",
    )
  end
end
