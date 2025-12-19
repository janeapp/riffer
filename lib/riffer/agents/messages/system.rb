# frozen_string_literal: true

module Riffer::Agents::Messages
  class System < Base
    def role
      "system"
    end
  end
end
