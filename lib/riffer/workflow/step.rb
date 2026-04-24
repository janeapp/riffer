# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Workflow::Step represents a single step in a workflow, which can be either an AgentStep or a custom step that implements the execute method.
# Each step can define its own input and output schemas, which are used to validate the data
class Riffer::Workflow::Step
    # Defines or returns the step's input schema. This is used to validate the input to the step and ensure it matches the expected format for the step's logic.
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

    # Defines or returns the step's output schema. This is used to validate the output of the step and ensure it matches the expected format for downstream steps or final workflow output.
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

    # Validates the input against the input schema and the execute output against the output schema
    #--
    #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
    def execute_with_validation(input)
        unless self.class.input_schema
            raise Riffer::Workflow::ConfigurationError, "Input schema is not defined"
        end
        unless self.class.output_schema
            raise Riffer::Workflow::ConfigurationError, "Output schema is not defined"
        end

        begin
            input_validated = self.class.input_schema&.validate(input) || input
        rescue => e
            raise Riffer::ValidationError.new("Input does not match input schema: #{e.message}")
        end
        
        output = execute(input_validated)

        begin 
            output_validated = self.class.output_schema&.validate(output) || output
        rescue => e
            raise Riffer::ValidationError.new("Output does not match output schema: #{e.message}")
        end
        output_validated
    end

    # Executes the step with the given input. This method should be overridden by subclasses to implement the actual logic of the step.
    #--
    #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
    def execute(input)
        raise NotImplementedError, "#{self.class} must implement #call"
    end
end
