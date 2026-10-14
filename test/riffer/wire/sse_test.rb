# frozen_string_literal: true

require "test_helper"

describe Riffer::Wire::SSE do
  let(:decoder) { Riffer::Wire::SSE.new }

  def decode(*chunks)
    events = []
    chunks.each { |chunk| decoder.feed(chunk) { |data, event| events << [data, event] } }
    events
  end

  it "yields the data of each event" do
    expect(decode("data: one\n\ndata: two\n\n")).must_equal [["one", nil], ["two", nil]]
  end

  it "yields the event name alongside the data" do
    expect(decode("event: message_start\ndata: {}\n\n")).must_equal [["{}", "message_start"]]
  end

  it "resets the event name after each event" do
    expect(decode("event: ping\ndata: a\n\ndata: b\n\n")).must_equal [%w[a ping], ["b", nil]]
  end

  it "joins multiple data lines with newlines" do
    expect(decode("data: line one\ndata: line two\n\n")).must_equal [["line one\nline two", nil]]
  end

  it "accepts CRLF and bare CR line endings" do
    events = decode("data: crlf\r\n\r\ndata: cr\r\rdata: lf\n\n")

    expect(events).must_equal [["crlf", nil], ["cr", nil], ["lf", nil]]
  end

  it "reassembles an event split across chunks" do
    expect(decode("da", "ta: {\"a\"", ":1}\n", "\n")).must_equal [["{\"a\":1}", nil]]
  end

  it "keeps a CRLF split across chunks as one line break" do
    expect(decode("data: x\r", "\n\r", "\n")).must_equal [["x", nil]]
  end

  it "holds back an event until its blank line arrives" do
    expect(decode("data: pending\n")).must_be_empty
  end

  it "strips only one leading space from the value" do
    expect(decode("data:  padded\n\ndata:tight\n\n")).must_equal [[" padded", nil], ["tight", nil]]
  end

  it "ignores comments and unknown fields" do
    expect(decode(": keep-alive\nid: 7\nretry: 100\ndata: x\n\n")).must_equal [["x", nil]]
  end

  it "skips blank lines that close no data" do
    expect(decode("\n\nevent: ping\n\n")).must_be_empty
  end
end
