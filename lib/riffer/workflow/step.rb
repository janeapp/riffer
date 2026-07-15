# frozen_string_literal: true
# rbs_inline: enabled

# Base class for workflow steps. Subclasses declare +input+/+output+ contracts
# and implement +#execute+.
#
#   class FormatMessage < Riffer::Workflow::Step
#     input do
#       required :message, String
#     end
#
#     output do
#       required :formatted, String
#     end
#
#     def execute(message:)
#       {formatted: message.upcase}
#     end
#   end
#
class Riffer::Workflow::Step
  # @rbs self.@input_params: Riffer::Params?
  # @rbs self.@output_params: Riffer::Params?
  # @rbs self.@identifier_value: String?
  # @rbs self.@uses: Array[Module]?
  # @rbs @context: Hash[Symbol, untyped]?

  # The workflow-level context passed at construction time.
  attr_reader :context #: Hash[Symbol, untyped]?

  #--
  #: (?context: Hash[Symbol, untyped]?) -> void
  def initialize(context: nil)
    @context = context
  end

  # Gets or sets the step identifier. Defaults to the snake_case class name.
  #--
  #: (?String?) -> String
  def self.identifier(value = nil)
    if value.nil?
      @identifier_value || Riffer::Helpers::ClassNameConverter.convert(name)
    else
      @identifier_value = value.to_s
    end
  end

  # Defines the input contract using the Params DSL.
  #--
  #: () ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> Riffer::Params?
  def self.input(&block)
    return @input_params if block.nil?
    builder = Riffer::Params.new
    builder.instance_eval(&block)
    @input_params = builder
  end

  # Defines the output contract using the Params DSL.
  #--
  #: () ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> Riffer::Params?
  def self.output(&block)
    return @output_params if block.nil?
    builder = Riffer::Params.new
    builder.instance_eval(&block)
    @output_params = builder
  end

  # Declares agents or tools this step depends on (for visualization).
  #--
  #: (*Module) -> Array[Module]
  def self.uses(*classes)
    return @uses || [] if classes.empty?

    classes.each do |cls|
      unless cls.is_a?(Module)
        raise Riffer::ArgumentError, "#{cls.inspect} is not a Module"
      end
    end

    registered = (@uses ||= []) #: Array[Module]
    registered.concat(classes)
  end

  # Executes the step. Subclasses must override this.
  #--
  #: (**untyped) -> Hash[Symbol, untyped]
  def execute(**kwargs)
    raise NotImplementedError, "#{self.class} must implement #execute"
  end
end
