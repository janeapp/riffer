# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Messages::Assistant < Riffer::Messages::Base
  ToolCall = Struct.new(:id, :call_id, :name, :arguments, keyword_init: true)

  attr_reader :tool_calls #: Array[Riffer::Messages::Assistant::ToolCall]

  attr_reader :token_usage #: Riffer::TokenUsage?

  attr_reader :structured_output #: Hash[Symbol, untyped]?

  #: (String, ?tool_calls: Array[Riffer::Messages::Assistant::ToolCall], ?token_usage: Riffer::TokenUsage?, ?structured_output: Hash[Symbol, untyped]?) -> void
  def initialize(content, tool_calls: [], token_usage: nil, structured_output: nil)
    super(content)
    @tool_calls = tool_calls
    @token_usage = token_usage
    @structured_output = structured_output
  end

  #: () -> Symbol
  def role
    :assistant
  end

  #: () -> bool
  def structured_output?
    !@structured_output.nil?
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = {role: role, content: content}
    hash[:tool_calls] = tool_calls.map(&:to_h) unless tool_calls.empty?
    hash[:token_usage] = token_usage.to_h if token_usage
    hash[:structured_output] = structured_output if structured_output?
    hash
  end
end
