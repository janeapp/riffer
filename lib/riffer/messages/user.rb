# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Messages::User < Riffer::Messages::Base
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::User)) -> Riffer::Messages::User
  def self.from_hash(msg)
    return msg if msg.is_a?(Riffer::Messages::User)

    files = (msg[:files] || []).map { |f| Riffer::Messages::User::FilePart.from_hash(f) }
    new(msg[:content], id: msg[:id], files: files)
  end

  attr_reader :files #: Array[Riffer::Messages::User::FilePart] # @dynamic files

  #--
  #: (String, ?id: String?, ?files: Array[Riffer::Messages::User::FilePart]) -> void
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
