# Riffer::Workflow::Result encapsulates the results of executing a workflow, including the output of each step and overall success status.
class Riffer::Workflow::Result
    attr_reader :steps

    def initialize
        @steps = []
    end

    # Adds the result of a step execution to the workflow result.
    #--
    #: (Riffer::Workflow::StepResult) -> void
    def add_step_result(step_result)
        @steps << step_result
    end

    # Returns true if all steps succeeded, false if any step failed.
    #--
    #: () -> bool
    def succeeded?
        @steps.all? { |step| step.success }
    end

    # Returns true if any step failed, false if all steps succeeded.
    #--
    #: () -> bool
    def failed?
        @steps.any? { |step| !step.success }
    end

    # Returns the output of the last step if the workflow succeeded, or nil if it failed.
    #--
    #: () -> untyped
    def result
        succeeded? ? @steps.last.output : nil
    end

    # Returns the error message of the first failed step if the workflow failed, or nil if it succeeded.
    #--
    #: () -> String?
    def error
        failed? ? @steps.find { |step| !step.success }.error : nil
    end
end
