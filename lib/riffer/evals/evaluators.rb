# frozen_string_literal: true

# Namespace for built-in evaluators and the evaluator registry.
#
# See Riffer::Evals::Evaluators::Registry for registering custom evaluators.
module Riffer::Evals::Evaluators
  # Registry for looking up evaluators by identifier.
  #
  # Built-in evaluators are automatically registered. Custom evaluators
  # can be registered using Registry.register.
  #
  #   # Register a custom evaluator
  #   Riffer::Evals::Evaluators::Registry.register(:my_evaluator, MyEvaluator)
  #
  #   # Find an evaluator
  #   Riffer::Evals::Evaluators::Registry.find("answer_relevancy")
  #   # => Riffer::Evals::Evaluators::AnswerRelevancy
  #
  module Registry
    class << self
      # Registers an evaluator class with an identifier.
      #
      # identifier:: String or Symbol - the identifier to register
      # evaluator_class:: Class - the evaluator class
      #
      # Returns void.
      def register(identifier, evaluator_class)
        registry[identifier.to_s] = evaluator_class
      end

      # Finds an evaluator class by identifier.
      #
      # identifier:: String or Symbol - the identifier to look up
      #
      # Returns Class or nil.
      def find(identifier)
        registry[identifier.to_s]
      end

      # Returns all registered evaluators.
      #
      # Returns Hash mapping identifiers to evaluator classes.
      def all
        registry.dup
      end

      # Clears all registered evaluators.
      #
      # Primarily for testing.
      #
      # Returns void.
      def clear
        @registry = {}
      end

      private

      def registry
        @registry ||= {}
      end
    end
  end
end
