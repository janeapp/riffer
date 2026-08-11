# frozen_string_literal: true
# rbs_inline: enabled

# Represents a user message in a conversation.
class Riffer::Messages::User < Riffer::Messages::Base
  # File attachments for this message.
  attr_reader :files #: Array[Riffer::Messages::FilePart]

  #--
  #: (String, ?id: String?, ?files: Array[Riffer::Messages::FilePart]) -> void
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
    hash = { role: role, content: content } #: Hash[Symbol, untyped]
    hash[:id] = id if id
    hash[:files] = files.map(&:to_h) unless files.empty?
    hash
  end
end
