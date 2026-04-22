class Riffer::Workflow::Result
    attr_reader :steps

    def initialize
        @steps = []
    end

    def add_step_result(step_result)
        @steps << step_result
    end

    def succeeded?
        @steps.all? { |step| step[:success] }
    end

    def result
        succeeded? ? @steps.last[:output] : nil
    end
end