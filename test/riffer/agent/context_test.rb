# frozen_string_literal: true

require "test_helper"

describe Riffer::Agent::Context do
  describe "construction" do
    it "defaults skills to nil" do
      expect(Riffer::Agent::Context.new.skills).must_be_nil
    end

    it "defaults token_usage to nil" do
      expect(Riffer::Agent::Context.new.token_usage).must_be_nil
    end

    it "exposes caller keys via #[]" do
      expect(Riffer::Agent::Context.new(user_id: 42)[:user_id]).must_equal 42
    end

    it "exposes caller keys via #dig" do
      expect(Riffer::Agent::Context.new(user_id: 42).dig(:user_id)).must_equal 42
    end

    it "returns nil for unknown keys" do
      expect(Riffer::Agent::Context.new[:missing]).must_be_nil
    end

    it "does not mutate the source hash" do
      source = {tenant: "alpha"}
      context = Riffer::Agent::Context.new(source)
      context.skills = nil
      context.token_usage = nil
      expect(source).must_equal({tenant: "alpha"})
    end

    it "raises when :skills is passed by the caller" do
      expect { Riffer::Agent::Context.new(skills: :nope) }
        .must_raise Riffer::ArgumentError
    end

    it "raises when :token_usage is passed by the caller" do
      expect { Riffer::Agent::Context.new(token_usage: :nope) }
        .must_raise Riffer::ArgumentError
    end

    it "raises when :mcp_progressive_tools is passed by the caller" do
      expect { Riffer::Agent::Context.new(mcp_progressive_tools: []) }
        .must_raise Riffer::ArgumentError
    end

    it "raises when :discovered_tools is passed by the caller" do
      expect { Riffer::Agent::Context.new(discovered_tools: []) }
        .must_raise Riffer::ArgumentError
    end
  end

  describe "#skills=" do
    let(:context) { Riffer::Agent::Context.new }

    it "accepts nil" do
      context.skills = nil
      expect(context.skills).must_be_nil
    end

    it "accepts a Riffer::Skills::Context" do
      skills = Riffer::Skills::Context.new(
        backend: Riffer::Skills::Backend.new,
        skills: {},
        adapter: Riffer::Skills::MarkdownAdapter.new(skill_activate_tool: Riffer::Skills::ActivateTool)
      )
      context.skills = skills
      expect(context.skills).must_be_same_as skills
    end

    it "raises on a non-Skills::Context, non-nil value" do
      expect { context.skills = :nope }.must_raise Riffer::ArgumentError
    end

    it "exposes the written value via #[] (hash-style read still works)" do
      skills = Riffer::Skills::Context.new(
        backend: Riffer::Skills::Backend.new,
        skills: {},
        adapter: Riffer::Skills::MarkdownAdapter.new(skill_activate_tool: Riffer::Skills::ActivateTool)
      )
      context.skills = skills
      expect(context[:skills]).must_be_same_as skills
    end
  end

  describe "#token_usage=" do
    let(:context) { Riffer::Agent::Context.new }

    it "accepts nil" do
      context.token_usage = nil
      expect(context.token_usage).must_be_nil
    end

    it "accepts a Riffer::Providers::TokenUsage" do
      usage = Riffer::Providers::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      context.token_usage = usage
      expect(context.token_usage).must_be_same_as usage
    end

    it "raises on a non-TokenUsage, non-nil value" do
      expect { context.token_usage = 42 }.must_raise Riffer::ArgumentError
    end

    it "exposes the written value via #[] (hash-style read still works)" do
      usage = Riffer::Providers::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      context.token_usage = usage
      expect(context[:token_usage]).must_be_same_as usage
    end
  end

  describe "#mcp_progressive_tools=" do
    let(:context) { Riffer::Agent::Context.new }

    it "accepts nil" do
      context.mcp_progressive_tools = nil
      expect(context.mcp_progressive_tools).must_be_nil
    end

    it "accepts an Array of Riffer::Tool subclasses" do
      tool = Class.new(Riffer::Tool)
      context.mcp_progressive_tools = [tool]
      expect(context.mcp_progressive_tools).must_equal [tool]
    end

    it "accepts an empty Array" do
      context.mcp_progressive_tools = []
      expect(context.mcp_progressive_tools).must_equal []
    end

    it "raises on a non-Array, non-nil value" do
      expect { context.mcp_progressive_tools = :nope }.must_raise Riffer::ArgumentError
    end

    it "raises when Array contains non-Tool entries" do
      expect { context.mcp_progressive_tools = [String] }.must_raise Riffer::ArgumentError
    end

    it "exposes the written value via #[] (hash-style read still works)" do
      tool = Class.new(Riffer::Tool)
      context.mcp_progressive_tools = [tool]
      expect(context[:mcp_progressive_tools]).must_equal [tool]
    end
  end

  describe "#discovered_tools=" do
    let(:context) { Riffer::Agent::Context.new }

    it "accepts nil" do
      context.discovered_tools = nil
      expect(context.discovered_tools).must_be_nil
    end

    it "accepts an Array of Riffer::Tool subclasses" do
      tool = Class.new(Riffer::Tool)
      context.discovered_tools = [tool]
      expect(context.discovered_tools).must_equal [tool]
    end

    it "accepts an empty Array" do
      context.discovered_tools = []
      expect(context.discovered_tools).must_equal []
    end

    it "raises on a non-Array, non-nil value" do
      expect { context.discovered_tools = :nope }.must_raise Riffer::ArgumentError
    end

    it "raises when Array contains non-Tool entries" do
      expect { context.discovered_tools = [String] }.must_raise Riffer::ArgumentError
    end

    it "exposes the written value via #[] (hash-style read still works)" do
      tool = Class.new(Riffer::Tool)
      context.discovered_tools = [tool]
      expect(context[:discovered_tools]).must_equal [tool]
    end
  end

  describe "#discover_tools" do
    let(:context) { Riffer::Agent::Context.new }

    def named_tool(identifier)
      n = identifier
      Class.new(Riffer::Tool).tap do |klass|
        klass.define_singleton_method(:name) { n }
        klass.define_singleton_method(:identifier) { n }
      end
    end

    it "accumulates tools from a nil start" do
      tool = named_tool("tool_a")
      context.discover_tools([tool])
      expect(context.discovered_tools).must_equal [tool]
    end

    it "extends an existing set" do
      tool_a = named_tool("tool_a")
      tool_b = named_tool("tool_b")
      context.discover_tools([tool_a])
      context.discover_tools([tool_b])
      expect(context.discovered_tools).must_include tool_a
      expect(context.discovered_tools).must_include tool_b
    end

    it "deduplicates by name" do
      tool = named_tool("tool_a")
      context.discover_tools([tool])
      context.discover_tools([tool])
      expect(context.discovered_tools.length).must_equal 1
    end

    it "returns the updated array" do
      tool = named_tool("tool_a")
      result = context.discover_tools([tool])
      expect(result).must_equal [tool]
    end
  end

  describe "#to_h" do
    it "returns the underlying hash" do
      expect(Riffer::Agent::Context.new(tenant: "alpha").to_h)
        .must_equal({tenant: "alpha", skills: nil, token_usage: nil, mcp_progressive_tools: nil, discovered_tools: nil})
    end

    it "returns a copy (caller mutations do not leak back)" do
      context = Riffer::Agent::Context.new(tenant: "alpha")
      context.to_h[:tenant] = "beta"
      expect(context[:tenant]).must_equal "alpha"
    end
  end
end
