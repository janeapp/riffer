# frozen_string_literal: true

require "test_helper"

describe Riffer::Workflow::Step do
    describe ".input_schema" do
        it "defines and returns the input schema when given a block" do
            class MyStep1 < Riffer::Workflow::Step
                input_schema do
                    required :name, String
                end
            end

            expect(MyStep1.input_schema).must_be_instance_of Riffer::Params
            expect(MyStep1.input_schema.parameters[0].name).must_equal(:name)
        end

        it "sets and returns the input schema when given a Riffer::Params object" do
            class MyStep2 < Riffer::Workflow::Step
            end

            params = Riffer::Params.new do
                required :age, Integer
            end

            MyStep2.input_schema(params)
            expect(MyStep2.input_schema).must_equal params
        end

        it "raises an error if given an invalid argument" do
            class MyStep3 < Riffer::Workflow::Step
            end

            expect { MyStep3.input_schema("invalid") }.must_raise Riffer::ArgumentError
        end
    end

    describe ".output_schema" do
        it "defines and returns the output schema when given a block" do
            class MyStep4 < Riffer::Workflow::Step
                output_schema do
                    required :result, String
                end
            end

            expect(MyStep4.output_schema).must_be_instance_of Riffer::Params
            expect(MyStep4.output_schema.parameters[0].name).must_equal(:result)
        end

        it "sets and returns the output schema when given a Riffer::Params object" do
            class MyStep5 < Riffer::Workflow::Step
            end

            params = Riffer::Params.new do
                required :success, T::Boolean
            end

            MyStep5.output_schema(params)
            expect(MyStep5.output_schema).must_equal params
        end

        it "raises an error if given an invalid argument" do
            class MyStep6 < Riffer::Workflow::Step
            end

            expect { MyStep6.output_schema("invalid") }.must_raise Riffer::ArgumentError
        end
    end

    describe "#execute" do
        it "raises NotImplementedError by default" do
            step = Riffer::Workflow::Step.new
            expect { step.execute({}) }.must_raise NotImplementedError
        end
    end
end