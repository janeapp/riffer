# frozen_string_literal: true

require "test_helper"

# Minimal fixture subclass used to exercise the base behavior provided by
# Riffer::ExternalAgent (record_message, accumulate_token_usage, on_message
# dispatch). Echoes the prompt back as the response content with a hardcoded
# token count.
class EchoExternalAgent < Riffer::ExternalAgent
  HARDCODED_USAGE = Riffer::TokenUsage.new(input_tokens: 1, output_tokens: 1)

  def generate(prompt_or_messages, files: nil, context: nil)
    record_message(Riffer::Messages::User.new(prompt_or_messages))
    record_message(Riffer::Messages::Assistant.new(prompt_or_messages))
    accumulate_token_usage(HARDCODED_USAGE)
    Riffer::ExternalAgent::Response.new(
      prompt_or_messages,
      messages: messages.dup,
      token_usage: token_usage
    )
  end
end

describe Riffer::ExternalAgent do
  describe "#initialize" do
    it "starts with empty messages" do
      expect(Riffer::ExternalAgent.new.messages).must_equal []
    end

    it "starts with nil token_usage" do
      expect(Riffer::ExternalAgent.new.token_usage).must_be_nil
    end
  end

  describe "AgentInterface contract" do
    it "raises NotImplementedError on #generate when not overridden" do
      expect { Riffer::ExternalAgent.new.generate("hi") }.must_raise NotImplementedError
    end

    it "raises NotImplementedError on #stream when not overridden" do
      expect { Riffer::ExternalAgent.new.stream("hi") }.must_raise NotImplementedError
    end
  end

  describe "#extract_telemetry" do
    it "raises NotImplementedError by default" do
      expect { Riffer::ExternalAgent.new.extract_telemetry({}) }.must_raise NotImplementedError
    end
  end

  describe "#on_message" do
    it "raises Riffer::ArgumentError without a block" do
      expect { Riffer::ExternalAgent.new.on_message }.must_raise Riffer::ArgumentError
    end

    it "returns self for chaining" do
      agent = Riffer::ExternalAgent.new
      expect(agent.on_message { |_| }).must_equal agent
    end

    it "fires the callback for each recorded message" do
      agent = EchoExternalAgent.new
      received = []
      agent.on_message { |m| received << m }
      agent.generate("ping")
      expect(received.size).must_equal 2
      expect(received.first).must_be_kind_of Riffer::Messages::User
      expect(received.last).must_be_kind_of Riffer::Messages::Assistant
    end
  end

  describe "subclass behavior" do
    it "accumulates messages across record_message calls" do
      agent = EchoExternalAgent.new
      agent.generate("first")
      agent.generate("second")
      expect(agent.messages.size).must_equal 4
    end

    it "sums token_usage across accumulate_token_usage calls" do
      agent = EchoExternalAgent.new
      agent.generate("first")
      agent.generate("second")
      expect(agent.token_usage.input_tokens).must_equal 2
      expect(agent.token_usage.output_tokens).must_equal 2
    end

    it "returns a Riffer::ExternalAgent::Response from generate" do
      response = EchoExternalAgent.new.generate("hello")
      expect(response).must_be_kind_of Riffer::ExternalAgent::Response
      expect(response.content).must_equal "hello"
    end
  end
end
