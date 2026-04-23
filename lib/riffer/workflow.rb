# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Workflow
    # Base error class for workflow-related errors.
    class Error < Riffer::Error; end
    # Raised when a step in the workflow fails to execute properly.
    # Contains the results of all steps executed up to the point of failure for debugging purposes.
    class StepExecutionError < Error
        attr_reader :results

        def initialize(message, results = nil)
            super(message)
            @results = results
        end
    end
    # Raised when validation of input or output schemas fails.
    class SchemaValidationError < Error; end
    # Raised when the workflow is misconfigured, such as missing steps or incompatible schemas.
    class ConfigurationError < Error; end
end

# Riffer::Workflow::Base provides a DSL for defining multi-step workflows.
#
# The Workflow::Base class provides class methods for defining the 
# workflow's input and output schemas, as well as the steps that make 
# up the workflow.
# Each step is a class that must implement a class method +execute+ 
# which takes an input hash and returns an output hash.
#
# Example usage:
#   class MyWorkflow < Riffer::Workflow::Base
#     input_schema do
#       required :city, String
#       optional :units, String
#     end
#     output_schema do
#       required :temperature, Float
#     end
#     step StepOne
#     step StepTwo
#   end
class Riffer::Workflow::Base

    # Returns the list of steps defined in the workflow. 
    # 
    # Steps are stored in the order they were added, and each step is 
    # an instance of a class that inherits from Riffer::Workflow::Step.
    #
    #--
    #: () -> Array[Riffer::Workflow::Step]
    def self.steps
        @steps ||= []
    end

    # Defines or returns the workflow's input schema.
    #
    # If a block is given, it evaluates the block to define the input schema.
    # If a Riffer::Params object is given, it sets that as the input schema
    #--
    #: (?Riffer::Params) ?{ () -> void } -> Riffer::Params
    def self.input_schema(params = nil, &block)
        if block
            @input_schema = Riffer::Params::new
            @input_schema.instance_eval(&block)
        elsif !params.nil?
            raise Riffer::ArgumentError, "input_schema must be a Riffer::Params" unless params.is_a?(Riffer::Params)
            @input_schema = params
        end
        @input_schema
    end

    # Defines or returns the workflow's output schema.
    #
    # If a block is given, it evaluates the block to define the output schema.
    # If a Riffer::Params object is given, it sets that as the output schema
    #--
    #: (?Riffer::Params) ?{ () -> void } -> Riffer::Params
    def self.output_schema(params = nil, &block)
        if block
            @output_schema = Riffer::Params::new
            @output_schema.instance_eval(&block)
        elsif !params.nil?
            raise Riffer::ArgumentError, "output_schema must be a Riffer::Params" unless params.is_a?(Riffer::Params)
            @output_schema = params
        end
        @output_schema
    end

    # Defines a step in the workflow.
    #
    # Validates that the step's input schema matches the workflow's input schema (for the first step)
    # and that each step's output schema matches the next step's input schema.
    # Requires the workflow have its input and output schemas defined before adding steps to ensure compatibility.
    #
    #--
    #: (Riffer::Workflow::Step) -> void
    def self.step(step_class)
        unless step_class.is_a?(Class) && step_class <= Riffer::Workflow::Step
            raise Riffer::ArgumentError, "step must be a class that inherits from Riffer::Workflow::Step"
        end

        # check if input_schema and output_schema are defined
        unless self.input_schema
            raise Riffer::Workflow::ConfigurationError, "Workflow input schema is not defined"
        end
        unless self.output_schema
            raise Riffer::Workflow::ConfigurationError, "Workflow output schema is not defined"
        end

        # check if step's input_schema and output_schema are defined
        unless step_class.input_schema
            raise Riffer::Workflow::ConfigurationError, "Input schema for step #{step_class} is not defined"
        end
        unless step_class.output_schema
            raise Riffer::Workflow::ConfigurationError, "Output schema for step #{step_class} is not defined"
        end

        # validate first step's input schema matches workflow input
        if self.steps.empty?
            workflow_input_schema = self.input_schema
            step_input_schema = step_class.input_schema
            if workflow_input_schema && step_input_schema && !workflow_input_schema.is_equal?(step_input_schema)
                raise Riffer::Workflow::SchemaValidationError, "Input schema of #{step_class} is not compatible with workflow input schema"
            end
        end

        # validate last output matches next input
        if self.steps.any?
            last_output_schema = self.steps.last.class.output_schema
            next_input_schema = step_class.input_schema
            if last_output_schema && next_input_schema && !last_output_schema.is_equal?(next_input_schema)
                raise Riffer::Workflow::SchemaValidationError, "Output schema of #{self.steps.last.class} is not compatible with input schema of #{step_class}"
            end
        end
        step = step_class.new
        self.steps << step
    end

    # Executes the workflow with the given input.
    #
    # Validates the input against the workflow's input schema, 
    # the last step's output schema against the workflow's output schema, 
    # then executes each step in order, passing the output of each step as the input to the next.
    # Collects the results of each step and returns a Riffer::Workflow::Result object 
    # containing each step's results and overall success status.
    # If any step raises an error during execution, the workflow halts and raises a StepExecutionError
    # with the results of all steps executed up to that point for debugging purposes.
    #
    #--
    #: (hash) -> Riffer::Workflow::Result
    def self.execute(input)
        # check if steps are defined
        unless self.steps && self.steps.any?
            raise Riffer::Workflow::ConfigurationError, "No steps defined in workflow"
        end

        #validate last step's output schema matches workflow output before executing
        output_schema = self.output_schema
        if output_schema && self.steps.any?
            last_output_schema = self.steps.last.class.output_schema
            if last_output_schema && !last_output_schema.is_equal?(output_schema)
                raise Riffer::Workflow::SchemaValidationError, "Output schema of #{steps.last.class} is not compatible with workflow output schema"
            end
        end

        # validate input matches workflow input
        self.input_schema.validate(input)

        current_input = input

        results = Riffer::Workflow::Result.new

        self.steps.each do |step|
            result = Riffer::Workflow::StepResult.new(step.class, current_input)
            begin
                output = step.execute(current_input)
                result.output = output
                result.success = true
                results.add_step_result(result)
                current_input = output
            rescue => e
                result.error = e.message
                result.success = false
                results.add_step_result(result)
                raise Riffer::Workflow::StepExecutionError.new("Error executing step #{step.class}: #{e.message}", results)
            end
        end

        results
    end
end
