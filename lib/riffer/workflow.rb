module Riffer
    module Workflow
        class Base
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

            def self.step(step_class)
                @steps ||= []
                step = step_class.new unless step.is_a?(Riffer::Workflow::Step)
                # validate first step's input schema matches workflow input
                if @steps.empty?
                    workflow_input_schema = self.input_schema
                    step_input_schema = step.class.input_schema
                    if workflow_input_schema && step_input_schema && !workflow_input_schema.is_equal?(step_input_schema)
                        raise Riffer::ValidationError, "Input schema of #{step_class} is not compatible with workflow input schema"
                    end
                end

                # validate last output matches next input
                if @steps.any?
                    last_output_schema = @steps.last.class.output_schema
                    next_input_schema = step.class.input_schema
                    if last_output_schema && next_input_schema && !last_output_schema.is_equal?(next_input_schema)
                        raise Riffer::ValidationError, "Output schema of #{@steps.last.class} is not compatible with input schema of #{step_class}"
                    end
                end
                @steps << step
            end

            def self.execute(input)
                #validate last step's output schema matches workflow output
                output_schema = self.output_schema
                if output_schema && @steps.any?
                    last_output_schema = @steps.last.class.output_schema
                    if last_output_schema && !last_output_schema.is_equal?(output_schema)
                        raise Riffer::ValidationError, "Output schema of #{steps.last.class} is not compatible with workflow output schema"
                    end
                end

                # validate input matches workflow input
                self.input_schema.validate(input)

                current_input = input

                results = Riffer::Workflow::Result.new

                @steps.each do |step|
                    result = {
                        step: step.class,
                        input: current_input
                    }
                    begin
                        output = step.execute(current_input)
                        result[:output] = output
                        result[:success] = true
                        results.add_step_result(result)
                        current_input = output
                    rescue => e
                        result[:error] = e.message
                        result[:success] = false
                        results.add_step_result(result)
                        break
                    end
                end

                results
            end
        end
    end
end