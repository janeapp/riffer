# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Workflow is the base class for all workflows in the Riffer framework.
#
# Subclass this to create your own workflows.
# Provides a simple DSL for defining steps.
# See Riffer::Agent.
# For now, we will support just Riffer::Agent; in the next commit, we will onboard Riffer::Tools
#
# In case of success, a Riffer::Workflow::Response is returned in the method run.
# The exceptions Riffer::ValidationError, Riffer::ArgumentError, Riffer::Error, and Riffer::TimeoutError
# are captured, and a response with the error is returned. All other exceptions are not being suppressed.
#
# In the example below, MyWorkflow defines 4 steps: search1, search2, search3, search4. search1 does not
# depends in any steps, search2 depends_on search1, search3 does not have any dependency, and
# search4 depends on search1 and search2. All results from previous steps are available for the current
# step to consume.
# If a step has no dependencies, it will receive the initial parameters passed to the method run.
#
#   class MyAgent < Riffer::Agent
#     model 'openai/gpt-4o'
#     instructions 'You are a helpful assistant.'
#   end
#
#   class MyWorkflow < Riffer::Workflow
#     step :search1, MyAgent
#     step :search2, MyAgent, depends_on: :search1
#     step :search3, MyAgent
#     step :search4, MyAgent, depends_on: [:search1, :search2]
#   end
#
#   workflow = MyWorkflow.new
#   workflow.run(context:nil, prompt: "Hello!")
#
class Riffer::Workflow
  extend Riffer::Toolable

  kind :workflow
  VALID_STEP_RESPONSE = [Riffer::Agent::Response].freeze
  DEFAULT_TIMEOUT = 60 #: Integer

  # We use a class instance variable to store steps for each specific subclass
  #
  #: () -> Array[Hash[Symbol, untyped]]
  def self.steps
    @steps ||= []
  end

  # 'DSL' method to define a step, for now accepting just Agent, we will update it latter
  #
  #--
  #: (Symbol, singleton(Riffer::Agent), ?Hash[Symbol, untyped]) -> Array[Hash[Symbol, untyped]]
  def self.step(name, agent_class, options = {})
    steps << {
      name: name,
      step_class: agent_class,
      depends_on: Array(options[:depends_on]) # Ensure it's always an array
    }
  end

  # Initializes a new workflow.
  #
  #--
  #: () -> void
  def initialize
    @results = {}
    @default_input = {}
    @context = {}
  end

  # Run all the workflow steps
  #
  #--
  #: (context: Hash[Symbol, untyped], **untyped) -> Riffer::Workflow::Response
  def run(context:, **kwargs)
    @context = context
    @default_input = kwargs

    self.class.steps.each do |step_config|
      @results[step_config[:name]] = run_step_with_validation(step_config: step_config)
    end

    Riffer::Workflow::Response.success(identifier: self.class.identifier, steps_response: @results)
  rescue Riffer::ValidationError, Riffer::ArgumentError, Riffer::Error => e
    Riffer::Workflow::Response.error(
      identifier: self.class.identifier, steps_response: @results, message: e.message, type: :validation_error
    )
  rescue Riffer::TimeoutError => e
    Riffer::Workflow::Response.error(
      identifier: self.class.identifier, steps_response: @results, message: e.message, type: :execution_error
    )
  end

  private

  # Executes the step with validation and timeout.
  #
  # Raises Riffer::ValidationError if validation fails.
  # Raises Riffer::TimeoutError if execution exceeds the configured timeout.
  # Raises Riffer::Error if the step(Agent) does not return a Response::Agent object.
  # Raises Riffer::ArgumentError if the step is not an Agent(we will update latter to accept Tool and Workflow).
  #
  #--
  #: (step_config: Hash[Symbol, untyped]) -> Riffer::Agent::Response
  def run_step_with_validation(step_config:)
    validated_args = generate_validated_args(step_config)

    result = Timeout.timeout(self.class.timeout) do
      agent = step_config[:step_class].new

      case agent
      when Riffer::Agent
        files = validated_args.delete(:files)
        prompt = validated_args.values.join(" ")
        agent = step_config[:step_class].new

        agent.generate(prompt, files:, context: @context)
      else
        raise Riffer::ArgumentError, "Unknown message step: #{step_config[:step_class]}"
      end
    end

    unless VALID_STEP_RESPONSE.any? { |cls| result.is_a?(cls) }
      raise Riffer::Error, "#{self.class} must return a Riffer::Response from #run"
    end

    result
  rescue Timeout::Error
    raise Riffer::TimeoutError, "Step execution timed out after #{self.class.timeout} seconds"
  end

  # Generate and validate the arguments for a step, if the class provide one
  #
  #--
  #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def generate_validated_args(step_config)
    params_builder = step_config[:step_class].respond_to?(:params) ? step_config[:step_class].params : nil
    sliced = @results.slice(*step_config[:depends_on])
    payload = sliced.empty? ? @default_input : sliced

    payload = payload.map do |_key, result|
      if result.respond_to?(:structured_output)
        result.structured_output
      elsif result.respond_to?(:content)
        {content: result.content}
      else
        {content: result}
      end
    end.reduce({}, :merge!)

    params_builder ? params_builder.validate(payload) : payload
  end
end
