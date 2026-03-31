# frozen_string_literal: true
# rbs_inline: enabled

# Represents a user message in a conversation.
#
#   msg = Riffer::Messages::User.new("Hello!")
#   msg.role     # => :user
#   msg.content  # => "Hello!"
#
#   msg = Riffer::Messages::User.new("Describe this image", files: [file_part])
#   msg.files    # => [#<Riffer::FilePart ...>]
#
class Riffer::Messages::User < Riffer::Messages::Base
  # File attachments for this message.
  attr_reader :files #: Array[Riffer::FilePart]

  # Initializes a user message.
  #
  #--
  #: (String, ?files: Array[Riffer::FilePart], ?timestamp: Time) -> void
  def initialize(content, files: [], timestamp: Time.now)
    super(content, timestamp: timestamp)
    @files = files
  end

  #--
  #: () -> Symbol
  def role
    :user
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = super
    hash[:files] = files.map(&:to_h) unless files.empty?
    hash
  end
end
