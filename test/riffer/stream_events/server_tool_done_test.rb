# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::ServerToolDone do
  let(:part) { Riffer::Messages::Assistant::ServerToolPart.new(name: "web_search", kind: :call, data: "{}", format: "mock-v1") }

  it "carries the server tool part" do
    expect(Riffer::StreamEvents::ServerToolDone.new(part).part).must_equal part
  end

  it "sets default role to assistant" do
    expect(Riffer::StreamEvents::ServerToolDone.new(part).role).must_equal :assistant
  end

  it "returns hash with role and the part" do
    expect(Riffer::StreamEvents::ServerToolDone.new(part).to_h).must_equal(
      { role: :assistant, part: { name: "web_search", kind: :call, data: "{}", format: "mock-v1" } },
    )
  end
end
