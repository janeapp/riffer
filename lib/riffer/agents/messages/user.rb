# frozen_string_literal: true

module Riffer::Agents::Messages
  class User < Base
    def role
      "user"
    end
  end
end
