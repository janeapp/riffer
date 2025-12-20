# frozen_string_literal: true

module Riffer::Tools
  class Base
    class << self
      def id(tool_id = nil)
        return @id if tool_id.nil?

        raise ArgumentError, "id must be a String" unless tool_id.is_a?(String)
        raise ArgumentError, "id cannot be empty" if tool_id.strip.empty?

        @id = tool_id
      end

      def description(desc = nil)
        return @description if desc.nil?

        raise ArgumentError, "description must be a String" unless desc.is_a?(String)
        raise ArgumentError, "description cannot be empty" if desc.strip.empty?

        @description = desc
      end

      def parameters(params = nil)
        return @parameters if params.nil?

        raise ArgumentError, "parameters must be a Hash" unless params.is_a?(Hash)

        @parameters = params
      end
    end

    def execute(**params)
      raise NotImplementedError, "Subclasses must implement #execute"
    end

    def to_openai_tool
      {
        type: "function",
        function: {
          name: self.class.id,
          description: self.class.description,
          parameters: self.class.parameters || {}
        }
      }
    end

    def schema
      {
        name: self.class.id,
        description: self.class.description,
        parameters: self.class.parameters || {}
      }
    end
  end
end
