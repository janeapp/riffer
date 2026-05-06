# frozen_string_literal: true

require "test_helper"

describe Riffer::AgentInterface do
  let(:stub_class) { Class.new { include Riffer::AgentInterface } }
  let(:stub) { stub_class.new }

  describe "#generate" do
    it "raises NotImplementedError" do
      expect { stub.generate("prompt") }.must_raise NotImplementedError
    end
  end

  describe "#stream" do
    it "raises NotImplementedError" do
      expect { stub.stream("prompt") }.must_raise NotImplementedError
    end
  end

  describe "#messages" do
    it "raises NotImplementedError" do
      expect { stub.messages }.must_raise NotImplementedError
    end
  end

  describe "#token_usage" do
    it "raises NotImplementedError" do
      expect { stub.token_usage }.must_raise NotImplementedError
    end
  end

  describe "#on_message" do
    it "raises NotImplementedError" do
      expect { stub.on_message { } }.must_raise NotImplementedError
    end
  end
end
