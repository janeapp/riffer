# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Anthropic::Client do
  let(:url) { "https://api.anthropic.com/v1/messages" }

  it "posts to the Messages API with the key and the pinned version" do
    stub = stub_request(:post, url).
      with(headers: { "x-api-key" => "secret", "anthropic-version" => "2023-06-01" }).
      to_return(status: 200, body: "{}")
    Riffer::Providers::Anthropic::Client.new(api_key: "secret").post("v1/messages", {})

    assert_requested stub
  end

  it "sends an overridden anthropic_version" do
    stub = stub_request(:post, url).
      with(headers: { "anthropic-version" => "2026-10-21" }).
      to_return(status: 200, body: "{}")
    Riffer::Providers::Anthropic::Client.new(api_key: "secret", anthropic_version: "2026-10-21").post("v1/messages", {})

    assert_requested stub
  end

  it "joins the path to a base_url with or without a trailing slash" do
    stub = stub_request(:post, "https://proxy.example.test/anthropic/v1/messages").to_return(status: 200, body: "{}")

    %w[https://proxy.example.test/anthropic https://proxy.example.test/anthropic/].each do |base_url|
      Riffer::Providers::Anthropic::Client.new(api_key: "secret", base_url: base_url).post("v1/messages", {})
    end

    assert_requested stub, times: 2
  end

  it "formats an Anthropic error as its type and message" do
    body = '{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}'
    stub_request(:post, url).to_return(status: 401, body: body)
    client = Riffer::Providers::Anthropic::Client.new(api_key: "secret")
    error = expect { client.post("v1/messages", {}) }.must_raise Riffer::APIError

    expect(error.message).must_equal "Anthropic API error (401): authentication_error: invalid x-api-key"
    expect([error.status, error.body]).must_equal [401, body]
  end

  it "falls back to the shared error message for another shape" do
    stub_request(:post, url).to_return(status: 502, body: "Bad Gateway")
    client = Riffer::Providers::Anthropic::Client.new(api_key: "secret")
    error = expect { client.post("v1/messages", {}) }.must_raise Riffer::APIError

    expect(error.message).must_equal "Anthropic API error (502): Bad Gateway"
  end
end
