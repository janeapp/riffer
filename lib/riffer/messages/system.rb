# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Messages::System < Riffer::Messages::Base
  #: () -> Symbol
  def role
    :system
  end
end
