# frozen_string_literal: true
# rbs_inline: enabled

# Represents a user message in a conversation.
#
#   msg = Riffer::Messages::User.new("Hello!")
#   msg.role     # => :user
#   msg.content  # => "Hello!"
#
class Riffer::Messages::User < Riffer::Messages::Base
  #: () -> Symbol
  def role
    :user
  end
end
