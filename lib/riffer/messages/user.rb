# frozen_string_literal: true

# Represents a user message in a conversation.
#
#   msg = Riffer::Messages::User.new("Hello!")
#   msg.role     # => "user"
#   msg.content  # => "Hello!"
#
class Riffer::Messages::User < Riffer::Messages::Base
  # Returns "user".
  def role
    "user"
  end
end
