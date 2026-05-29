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

  describe "#to_h" do
    it "returns the underlying hash" do
      expect(Riffer::Agent::Context.new(tenant: "alpha").to_h)
        .must_equal({tenant: "alpha", skills: nil, token_usage: nil})
    end

    it "returns a copy (caller mutations do not leak back)" do
      context = Riffer::Agent::Context.new(tenant: "alpha")
      context.to_h[:tenant] = "beta"
      expect(context[:tenant]).must_equal "alpha"
    end
  end
end
