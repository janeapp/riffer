# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Messages::User < Riffer::Messages::Base
  attr_reader :files #: Array[Riffer::FilePart]

  #: (String, ?files: Array[Riffer::FilePart]) -> void
  def initialize(content, files: [])
    super(content)
    @files = files
  end

  #: () -> Symbol
  def role
    :user
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = {role: role, content: content}
    hash[:files] = files.map(&:to_h) unless files.empty?
    hash
  end
end
