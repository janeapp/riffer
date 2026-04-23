# Riffer::Workflow::StepResult encapsulates the results of executing a step in the workflow, including the input, output, success status, and any error message.
class Riffer::Workflow::StepResult
    #--
    #: (Riffer::Workflow::Step, untyped) -> void
    def initialize(step, input)
        @step = step
        @input = input
        @output = nil
        @success = false
        @error = nil
    end

    attr_accessor :step, :input, :output, :success, :error
end
