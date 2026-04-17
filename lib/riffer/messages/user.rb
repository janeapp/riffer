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
  #: (String, ?id: String?, ?files: Array[Riffer::FilePart]) -> void
  def initialize(content, id: nil, files: [])
    super(content, id: id)
    @files = files
  end

  #--
  #: () -> Symbol
  def role
    :user
  end

  #--
  #: (Riffer::Messages::User) -> Riffer::Messages::User
  def +(other)
    self.class.new("#{content}\n\n#{other.content}", files: files + other.files)
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = {role: role, content: content}
    hash[:id] = id unless id.nil?
    hash[:files] = files.map(&:to_h) unless files.empty?
    hash
  end
end
