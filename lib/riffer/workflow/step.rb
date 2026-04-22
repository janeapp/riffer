module Riffer
    module Workflow
        class Step
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

            def execute(input)
                raise NotImplementedError, "#{self.class} must implement #call"
            end
        end
    end
end
