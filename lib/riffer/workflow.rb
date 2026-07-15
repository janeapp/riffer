# frozen_string_literal: true
# rbs_inline: enabled

# Base class for workflows. Subclass it and declare steps to build a sequential
# pipeline.
#
#   class HelpDeskWorkflow < Riffer::Workflow
#     step CategorizeRequest
#     step FetchAccount
#     step DraftReply
#   end
#
#   result = HelpDeskWorkflow.execute(
#     {message: "I can't log in"},
#     context: {patient_id: "patient_123"}
#   )
#
class Riffer::Workflow
  # @rbs self.@steps: Array[singleton(Riffer::Workflow::Step)]?
  # @rbs self.@identifier_value: String?
  # @rbs @context: Hash[Symbol, untyped]?

  # The workflow-level context.
  attr_reader :context #: Hash[Symbol, untyped]?

  # Gets or sets the workflow identifier. Defaults to the snake_case class name.
  #--
  #: (?String?) -> String
  def self.identifier(value = nil)
    if value.nil?
      @identifier_value || Riffer::Helpers::ClassNameConverter.convert(name)
    else
      @identifier_value = value.to_s
    end
  end

  # Registers a step class in the workflow pipeline.
  #--
  #: (singleton(Riffer::Workflow::Step)) -> void
  def self.step(step_class)
    unless step_class.is_a?(Class) && step_class < Riffer::Workflow::Step
      raise Riffer::ArgumentError, "#{step_class} is not a Riffer::Workflow::Step subclass"
    end

    registered = (@steps ||= []) #: Array[singleton(Riffer::Workflow::Step)]
    id = step_class.identifier

    if id.empty?
      raise Riffer::ArgumentError, "#{step_class} has no name; set an explicit identifier with `identifier \"my_step\"`"
    end

    if registered.any? { |s| s.identifier == id }
      raise Riffer::ArgumentError, "duplicate step identifier: #{id.inspect}"
    end

    registered << step_class
  end

  # Returns the registered step classes.
  #--
  #: () -> Array[singleton(Riffer::Workflow::Step)]
  def self.steps
    @steps || [] #: Array[singleton(Riffer::Workflow::Step)]
  end

  # Convenience class method. Creates a new instance and runs the workflow.
  #--
  #: (Hash[Symbol, untyped], ?context: Hash[Symbol, untyped]?) -> Riffer::Workflow::Result
  def self.execute(input, context: nil)
    new(context: context).execute(**input)
  end

  # Returns a Mermaid flowchart string of the step pipeline.
  #--
  #: () -> String
  def self.to_mermaid
    lines = ["graph LR"]

    if steps.any?
      lines << "  subgraph #{identifier}"
      nodes = steps.map { |s| mermaid_node(s) }
      nodes.each_cons(2) { |a, b| lines << "    #{a} --> #{b}" }
      lines << "    #{nodes.first}" if nodes.size == 1
      lines << "  end"
    end

    lines.join("\n")
  end

  # Prints a text summary of the workflow to +$stdout+.
  #--
  #: () -> void
  def self.describe
    puts "#{identifier} (#{steps.size} steps)"
    steps.each_with_index do |step, i|
      input_fields = step.input&.parameters&.map(&:name) || []
      output_fields = step.output&.parameters&.map(&:name) || []
      line = "  #{i + 1}. #{step.identifier}  [#{input_fields.join(", ")}] → [#{output_fields.join(", ")}]"
      deps = step.uses
      line += "  · #{deps.map(&:name).join(", ")}" if deps.any?
      puts line
    end
  end

  #--
  #: (singleton(Riffer::Workflow::Step)) -> String
  def self.mermaid_node(step)
    deps = step.uses
    if deps.any?
      label = "#{step.identifier} · #{deps.map(&:name).join(", ")}"
      "#{step.identifier}[\"#{label}\"]"
    else
      step.identifier
    end
  end
  private_class_method :mermaid_node

  #--
  #: (?context: Hash[Symbol, untyped]?) -> void
  def initialize(context: nil)
    @context = context&.dup
  end

  # Runs the workflow pipeline with the given input.
  #--
  #: (**untyped) -> Riffer::Workflow::Result
  def execute(**input)
    Riffer::Workflow::Runner.execute(
      steps: self.class.steps,
      input: input,
      context: @context
    )
  end
end
