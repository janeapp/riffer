# frozen_string_literal: true

require "test_helper"

describe Riffer::AgentTool do
  let(:agent_class) do
    Class.new(Riffer::Agent) do
      identifier "research-agent"
      model "mock/riffer-1"
      description "Researches topics and returns summaries"
    end
  end

  describe ".identifier_for" do
    it "returns identifier with agent__ prefix" do
      expect(Riffer::AgentTool.identifier_for(agent_class)).must_equal "agent__research-agent"
    end

    it "replaces slashes with double underscores" do
      nested = Class.new(Riffer::Agent) do
        identifier "team/research-agent"
        model "mock/riffer-1"
        description "A nested agent"
      end

      expect(Riffer::AgentTool.identifier_for(nested)).must_equal "agent__team__research-agent"
    end
  end

  describe ".build" do
    it "creates a Tool subclass" do
      tool_class = Riffer::AgentTool.build(agent_class)
      expect(tool_class.superclass).must_equal Riffer::Tool
    end

    it "sets the correct identifier" do
      tool_class = Riffer::AgentTool.build(agent_class)
      expect(tool_class.name).must_equal "agent__research-agent"
    end

    it "sets the description from agent" do
      tool_class = Riffer::AgentTool.build(agent_class)
      expect(tool_class.description).must_equal "Researches topics and returns summaries"
    end

    it "defines a message parameter" do
      tool_class = Riffer::AgentTool.build(agent_class)
      schema = tool_class.parameters_schema
      expect(schema[:properties]["message"]).wont_be_nil
      expect(schema[:required]).must_include "message"
    end

    it "raises when agent has no description" do
      no_desc = Class.new(Riffer::Agent) do
        identifier "no-desc-agent"
        model "mock/riffer-1"
      end

      error = expect { Riffer::AgentTool.build(no_desc) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/must have a description/)
    end

    it "raises NotImplementedError when call is invoked" do
      tool_class = Riffer::AgentTool.build(agent_class)
      tool = tool_class.new

      expect { tool.call(context: nil, message: "test") }.must_raise(NotImplementedError)
    end
  end
end
