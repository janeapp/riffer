# frozen_string_literal: true

# Namespace for built-in evaluators and the evaluator repository.
#
# See Riffer::Evals::Evaluators::Repository for registering custom evaluators.
module Riffer::Evals::Evaluators
  # Repository for looking up evaluators by identifier.
  #
  # Built-in evaluators are always available. Custom evaluators
  # can be registered using Repository.register in your app initialization.
  #
  #   # Register a custom evaluator (config/initializers/riffer.rb)
  #   Riffer::Evals::Evaluators::Repository.register(:my_evaluator, MyEvaluator)
  #
  #   # Find an evaluator
  #   Riffer::Evals::Evaluators::Repository.find(:answer_relevancy)
  #   # => Riffer::Evals::Evaluators::AnswerRelevancy
  #
  class Repository
    # Built-in evaluators (always available).
    BUILT_IN = {
      answer_relevancy: -> { Riffer::Evals::Evaluators::AnswerRelevancy }
    }.freeze

    @custom = {}

    class << self
      # Registers a custom evaluator class with an identifier.
      #
      # identifier:: String or Symbol - the identifier to register
      # evaluator_class:: Class - the evaluator class
      #
      # Returns void.
      def register(identifier, evaluator_class)
        @custom[identifier.to_sym] = -> { evaluator_class }
      end

      # Finds an evaluator class by identifier.
      #
      # identifier:: String or Symbol - the identifier to look up
      #
      # Returns Class or nil.
      def find(identifier)
        id = identifier.to_sym
        (@custom[id] || BUILT_IN[id])&.call
      end

      # Returns all registered evaluators (built-in and custom).
      #
      # Returns Hash mapping identifiers to evaluator classes.
      def all
        BUILT_IN.merge(@custom).transform_values(&:call)
      end

      # Clears custom registrations (for testing). Built-ins remain.
      #
      # Returns void.
      def clear
        @custom = {}
      end
    end
  end
end
