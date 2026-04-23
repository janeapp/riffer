# frozen_string_literal: true
# rbs_inline: enabled

module Riffer
    module Workflow
        # Base error class for workflow-related errors.
        class Error < Riffer::Error; end
        # Raised when a step in the workflow fails to execute properly.
        class StepExecutionError < Error; end
        # Raised when validation of input or output schemas fails.
        class SchemaValidationError < Error; end
        # Raised when the workflow is misconfigured, such as missing steps or incompatible schemas.
        class ConfigurationError < Error; end

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
        #       required :city, String, description: "The city name"
        #     end
        #     output_schema do
        #       required :temperature, Float, description: "The current temperature in the city"
        #     end
        #     step StepOne
        #     step StepTwo
        #   end
        class Base
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
                elsif params.nil?
                    @input_schema
                else
                    raise Riffer::ArgumentError, "input_schema must be a Riffer::Params" unless params.is_a?(Riffer::Params)
                    @input_schema = params
                end
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
                elsif params.nil?
                    @output_schema
                else
                    raise Riffer::ArgumentError, "output_schema must be a Riffer::Params" unless params.is_a?(Riffer::Params)
                    @output_schema = params
                end
            end

            # Defines a step in the workflow.
            #
            # Validates that the step's input schema matches the workflow's input schema (for the first step)
            # and that each step's output schema matches the next step's input schema.
            #
            #--
            #: (Riffer::Workflow::Step) -> void
            def self.step(step_class)
                @steps ||= []
                step = step_class.new unless step.is_a?(Riffer::Workflow::Step)
                # validate first step's input schema matches workflow input
                if @steps.empty?
                    workflow_input_schema = self.input_schema
                    step_input_schema = step.class.input_schema
                    if workflow_input_schema && step_input_schema && !workflow_input_schema.is_equal?(step_input_schema)
                        raise Riffer::Workflow::SchemaValidationError, "Input schema of #{step_class} is not compatible with workflow input schema"
                    end
                end

                # validate last output matches next input
                if @steps.any?
                    last_output_schema = @steps.last.class.output_schema
                    next_input_schema = step.class.input_schema
                    if last_output_schema && next_input_schema && !last_output_schema.is_equal?(next_input_schema)
                        raise Riffer::Workflow::SchemaValidationError, "Output schema of #{@steps.last.class} is not compatible with input schema of #{step_class}"
                    end
                end
                @steps << step
            end

            # Executes the workflow with the given input.
            #
            # Validates the input against the workflow's input schema, then executes each step in order, passing the output of each step as the input to the next.
            # Collects the results of each step, including any errors, and returns a Riffer
            # Workflow::Result object containing the step results and overall success status.
            #
            #--
            #: (hash) -> Riffer::Workflow::Result
            def self.execute(input)
                # check if steps are defined
                unless @steps && @steps.any?
                    raise Riffer::Workflow::ConfigurationError, "No steps defined in workflow"
                end

                #validate last step's output schema matches workflow output before executing
                output_schema = self.output_schema
                if output_schema && @steps.any?
                    last_output_schema = @steps.last.class.output_schema
                    if last_output_schema && !last_output_schema.is_equal?(output_schema)
                        raise Riffer::Workflow::SchemaValidationError, "Output schema of #{steps.last.class} is not compatible with workflow output schema"
                    end
                end

                # validate input matches workflow input
                self.input_schema.validate(input)

                current_input = input

                results = Riffer::Workflow::Result.new

                @steps.each do |step|
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
                        throw Riffer::Workflow::StepExecutionError, "Error executing step #{step.class}: #{e.message}"
                    end
                end

                results
            end
        end
    end
end
