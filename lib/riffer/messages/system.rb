# frozen_string_literal: true
# rbs_inline: enabled

# Represents a system message (instructions) in a conversation.
#
#   msg = Riffer::Messages::System.new("You are a helpful assistant.")
#   msg.role     # => :system
#   msg.content  # => "You are a helpful assistant."
#
class Riffer::Messages::System < Riffer::Messages::Base
  #: return: Symbol
  def role
    :system
  end
end
