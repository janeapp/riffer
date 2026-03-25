# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Messages::Tool < Riffer::Messages::Base
  attr_reader :tool_call_id #: String
  attr_reader :name #: String
  attr_reader :error #: String?
  attr_reader :error_type #: Symbol?

  #: (String, tool_call_id: String, name: String, ?error: String?, ?error_type: Symbol?) -> void
  def initialize(content, tool_call_id:, name:, error: nil, error_type: nil)
    super(content)
    @tool_call_id = tool_call_id
    @name = name
    @error = error
    @error_type = error_type
  end

  #: () -> bool
  def error?
    !@error.nil?
  end

  #: () -> Symbol
  def role
    :tool
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = {role: role, content: content, tool_call_id: tool_call_id, name: name}
    if error?
      hash[:error] = error
      hash[:error_type] = error_type
    end
    hash
  end
end
