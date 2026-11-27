# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Messages::Tool < Riffer::Messages::Base
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::Tool)) -> Riffer::Messages::Tool
  def self.from_hash(msg)
    return msg if msg.is_a?(Riffer::Messages::Tool)

    if msg.values_at(:tool_call_id, :name).any?(&:nil?)
      raise Riffer::ArgumentError, "Tool message hash must include :tool_call_id and :name"
    end

    # An empty result is "", which a source that drops blank strings omits.
    new(
      msg[:content] || "",
      id: msg[:id],
      tool_call_id: msg[:tool_call_id],
      name: msg[:name],
      error: msg[:error],
      error_type: msg[:error_type]&.to_sym,
      loaded_tools: msg[:loaded_tools] || [],
      loaded_tools_description: msg[:loaded_tools_description],
    )
  end

  attr_reader :tool_call_id #: String # @dynamic tool_call_id
  attr_reader :name #: String # @dynamic name
  attr_reader :error #: String? # @dynamic error
  attr_reader :error_type #: Symbol? # @dynamic error_type
  attr_reader :loaded_tools #: Array[String] # @dynamic loaded_tools
  attr_reader :loaded_tools_description #: String? # @dynamic loaded_tools_description

  #--
  #: (String, tool_call_id: String, name: String, ?id: String?, ?error: String?, ?error_type: Symbol?, ?loaded_tools: Array[String], ?loaded_tools_description: String?) -> void
  def initialize(content, tool_call_id:, name:, id: nil, error: nil, error_type: nil, loaded_tools: [],
                 loaded_tools_description: nil)
    super(content, id: id)
    @tool_call_id = tool_call_id
    @name = name
    @error = error
    @error_type = error_type
    @loaded_tools = loaded_tools
    @loaded_tools_description = loaded_tools_description
  end

  #--
  #: () -> bool
  def error?
    !@error.nil?
  end

  #--
  #: () -> Symbol
  def role
    :tool
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = { role: role, content: content, tool_call_id: tool_call_id, name: name } #: Hash[Symbol, untyped]
    hash[:id] = id if id
    if error?
      hash[:error] = error
      hash[:error_type] = error_type
    end
    hash[:loaded_tools] = loaded_tools unless loaded_tools.empty?
    hash[:loaded_tools_description] = loaded_tools_description if loaded_tools_description
    hash
  end
end
